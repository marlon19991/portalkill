extends Node2D
## Orquestador del tower defense: arma la torre, gestiona casillas/trampas,
## oleadas, economía, toques, cámara (shake), hitstop, pausa y modo autotest.

var tower: Tower
var director: WaveDirector
var enemies_root: Node2D
var traps_root: Node2D
var slot_layer: SlotLayer
var camera: Camera2D
var hud: Hud
var overlay: Overlay
var world: Node2D
var traps: Dictionary = {} ## Vector2i(piso, casilla) -> Trap
var selected := Vector2i(-1, -1)
var speed := 1.0

var _trauma := 0.0
var _hitstop_until := 0
var _noise := FastNoiseLite.new()
var _time := 0.0
var _last_us := 0

# autotest
var _shots: Array = [3.0, 20.0, 45.0, 80.0, 120.0, 170.0]
var _shot_dir := ""
var _duration := 60.0
var _stat_t := 0.0
var _bot_t := 0.0
var _fps_samples: Array[float] = []
var _panel_test := "" ## autotest: deja el panel "build" o "trap" abierto para capturas
const BOT_PLAN := [
	[0, 2, &"saw"], [0, 1, &"sprinkler"], [1, 1, &"tesla"], [0, 3, &"turret"], [1, 3, &"oil"],
	[1, 4, &"flame"], [2, 2, &"piston"], [2, 1, &"saw"], [3, 2, &"tesla"], [2, 3, &"turret"],
	[3, 1, &"sprinkler"], [3, 3, &"flame"], [0, 0, &"saw"], [2, 0, &"oil"], [2, 4, &"flame"],
]

func _ready() -> void:
	var f := ThemeDB.fallback_font
	if f is FontFile:
		(f as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_NONE
		(f as FontFile).hinting = TextServer.HINTING_NONE
	_parse_args()
	_build()
	_new_run()

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shot_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--duration="):
			_duration = float(a.trim_prefix("--duration="))
		elif a.begins_with("--timescale="):
			speed = float(a.trim_prefix("--timescale="))
		elif a.begins_with("--shotevery="):
			var every := float(a.trim_prefix("--shotevery="))
			_shots.clear()
			var t := every
			while t < 3000.0:
				_shots.append(t)
				t += every
		elif a.begins_with("--panel="):
			_panel_test = a.trim_prefix("--panel=")
		elif a == "--stress":
			Game.stress = true
		elif a.begins_with("--gore="):
			Game.gore = int(a.trim_prefix("--gore="))

func _build() -> void:
	world = Node2D.new()
	add_child(world)
	tower = Tower.new()
	world.add_child(tower)
	Game.level = tower

	var blood := BloodSystem.new()
	blood.z_index = 6
	world.add_child(blood)
	Game.blood = blood

	# portales: start (verde), traspasos (naranja) y finish (rojo)
	for f in Tower.FLOORS:
		var p_in := Portal.new()
		p_in.setup(Color(0.4, 1.0, 0.6) if f == 0 else Color(1.0, 0.5, 0.15))
		p_in.position = Vector2(Tower.start_x(f), Tower.ground_y(f) - 17.0)
		p_in.z_index = 2
		world.add_child(p_in)
		var p_out := Portal.new()
		p_out.setup(Color(1.0, 0.15, 0.25) if f == Tower.FLOORS - 1 else Color(1.0, 0.5, 0.15))
		p_out.position = Vector2(Tower.end_x(f), Tower.ground_y(f) - 17.0)
		p_out.z_index = 2
		world.add_child(p_out)

	traps_root = Node2D.new()
	traps_root.z_index = 3
	world.add_child(traps_root)
	enemies_root = Node2D.new()
	enemies_root.z_index = 4
	world.add_child(enemies_root)

	var gibs := GibSystem.new()
	gibs.z_index = 5
	world.add_child(gibs)
	Game.gibs = gibs
	var proj := ProjectileSystem.new()
	proj.z_index = 7
	world.add_child(proj)
	Game.projectiles = proj
	var fx := FxSystem.new()
	fx.z_index = 8
	world.add_child(fx)
	Game.fx = fx
	slot_layer = SlotLayer.new()
	slot_layer.z_index = 9
	slot_layer.traps = traps
	world.add_child(slot_layer)

	camera = Camera2D.new()
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(camera)
	camera.make_current()

	director = WaveDirector.new()
	add_child(director)
	director.spawn_requested.connect(_spawn_enemy)
	director.all_waves_cleared.connect(func() -> void: _end(true))

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = Hud.new()
	hud.director = director
	ui.add_child(hud)
	overlay = Overlay.new()
	ui.add_child(overlay)
	hud.build_requested.connect(_build_trap)
	hud.upgrade_requested.connect(_upgrade_selected)
	hud.sell_requested.connect(_sell_selected)
	hud.cancel_requested.connect(func() -> void: _select(Vector2i(-1, -1)))
	hud.start_wave_requested.connect(func() -> void: director.start_now())
	hud.speed_toggled.connect(_toggle_speed)
	hud.gore_toggled.connect(func() -> void: Game.gore = (Game.gore + 1) % 3)
	hud.pause_toggled.connect(_toggle_pause)

	_noise.frequency = 0.9
	Events.screen_shake.connect(func(t: float) -> void: _trauma = minf(1.0, _trauma + t))
	Events.hitstop.connect(_on_hitstop)
	Events.enemy_leaked.connect(func(_e: Node2D, _n: int) -> void:
		if Game.lives <= 0:
			_end(false))
	process_mode = Node.PROCESS_MODE_ALWAYS
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	director.process_mode = Node.PROCESS_MODE_PAUSABLE

func _new_run() -> void:
	Game.reset_run()
	for e in Game.enemies:
		e.queue_free()
	Game.enemies.clear()
	for t in traps.values():
		t.queue_free()
	traps.clear()
	Game.projectiles.clear()
	Game.fx.clear()
	Game.gibs.clear()
	Game.blood.clear()
	director.reset()
	_select(Vector2i(-1, -1))
	overlay.show_mode(Overlay.Mode.NONE)
	get_tree().paused = false
	Engine.time_scale = speed
	tower.queue_redraw()

func _spawn_enemy(d: EnemyData, wave: int) -> void:
	var e := Enemy.new()
	e.setup(d, wave)
	enemies_root.add_child(e)
	Game.enemies.append(e)
	Events.enemy_spawned.emit(e)

func _end(victory: bool) -> void:
	if overlay.mode == Overlay.Mode.DEFEAT or overlay.mode == Overlay.Mode.VICTORY:
		return
	director.finished = true
	Events.game_over.emit(victory)
	overlay.show_mode(Overlay.Mode.VICTORY if victory else Overlay.Mode.DEFEAT)
	if Game.autotest:
		print("[autotest] %s en oleada %d, vidas=%d bajas=%d" % ["VICTORIA" if victory else "DERROTA", Game.wave, Game.lives, Game.kills])

# ---------------------------------------------------------------- casillas y trampas

func _select(key: Vector2i) -> void:
	selected = key
	slot_layer.selected = key
	slot_layer.preview = null
	hud.selected_slot = key
	hud.selected_trap = traps.get(key) if key.x >= 0 else null

func _build_trap(id: StringName) -> void:
	if selected.x < 0 or traps.has(selected):
		return
	var d := Catalog.trap(id)
	if not Game.spend(d.cost):
		return
	var t := Trap.new()
	t.setup(d, selected.x, selected.y)
	traps_root.add_child(t)
	traps[selected] = t
	Game.fx.burst(t.position, 16, d.color, 80.0)
	Game.fx.dust(Vector2(t.position.x, Tower.ground_y(selected.x)), 8)
	_select(selected) # pasa a mostrar el panel de la trampa

func _upgrade_selected() -> void:
	var t: Trap = traps.get(selected)
	if t and t.level < Trap.MAX_LEVEL and Game.spend(t.upgrade_cost()):
		t.upgrade()

func _sell_selected() -> void:
	var t: Trap = traps.get(selected)
	if t == null:
		return
	Game.add_gold(t.sell_value())
	Game.fx.float_text("+%d" % t.sell_value(), t.position + Vector2(0, -10), Color(1, 0.85, 0.3))
	Game.fx.sparks(t.position, 10, t.data.color)
	traps.erase(selected)
	t.queue_free()
	_select(selected)

func _toggle_speed() -> void:
	speed = 2.0 if speed < 2.0 else 1.0
	hud.speed = int(speed)
	Engine.time_scale = speed

func _toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	overlay.show_mode(Overlay.Mode.PAUSE if p else Overlay.Mode.NONE)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F3: hud.debug = not hud.debug
			KEY_ESCAPE, KEY_P: _toggle_pause()
			KEY_SPACE: director.start_now()
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	match overlay.mode:
		Overlay.Mode.PAUSE:
			_toggle_pause()
			return
		Overlay.Mode.DEFEAT, Overlay.Mode.VICTORY:
			if overlay._t > 0.8:
				_new_run()
			return
	if hud.handle_tap(p):
		return
	# toque en la torre: buscar casilla
	var f := Tower.floor_at(p.y)
	for s in Tower.SLOT_X.size():
		if Tower.slot_rect(f, s).has_point(p):
			var key := Vector2i(f, s)
			_select(Vector2i(-1, -1) if key == selected else key)
			return
	_select(Vector2i(-1, -1))

# ---------------------------------------------------------------- cámara, hitstop, autotest

func _on_hitstop(d: float) -> void:
	var until := Time.get_ticks_msec() + int(d * 1000.0)
	if until > _hitstop_until:
		_hitstop_until = until
	Engine.time_scale = speed * 0.05

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real := 0.016 if _last_us == 0 else (now - _last_us) / 1000000.0
	_last_us = now
	if Engine.time_scale < speed and Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = speed
	_time += real
	_trauma = maxf(0.0, _trauma - real * 1.6)
	var s := _trauma * _trauma
	camera.offset = (Vector2(_noise.get_noise_2d(_time * 60.0, 0.0), _noise.get_noise_2d(0.0, _time * 60.0)) * 6.0 * s).round()
	if Game.autotest:
		_autotest(real)

func _autotest(real: float) -> void:
	var delta := real * speed
	_stat_t += delta
	_bot_t -= delta
	_fps_samples.append(1.0 / maxf(real, 0.0001))
	var game_t := Time.get_ticks_msec() / 1000.0 * speed
	if _bot_t <= 0.0 and overlay.mode == Overlay.Mode.NONE:
		_bot_t = 1.0
		_bot_step()
	if _stat_t >= 5.0:
		_stat_t = 0.0
		var avg := 0.0
		var mn := INF
		for v in _fps_samples:
			avg += v
			mn = minf(mn, v)
		avg /= maxf(1.0, _fps_samples.size())
		_fps_samples.clear()
		print("[autotest] t=%.0f oleada=%d vidas=%d oro=%d trampas=%d fps_avg=%.0f fps_min=%.0f enemigos=%d sangre=%d gibs=%d fx=%d bajas=%d" % [
			game_t, Game.wave, Game.lives, Game.gold, traps.size(), avg, mn, Game.enemies.size(),
			Game.blood.count(), Game.gibs.gibs.size(), Game.fx.count(), Game.kills])
	if not _shots.is_empty() and game_t >= _shots[0]:
		_shots.pop_front()
		if _shot_dir != "":
			var path := "%s/shot_%03d.png" % [_shot_dir, int(game_t)]
			get_viewport().get_texture().get_image().save_png(path)
			print("[autotest] captura ", path)
	if game_t >= _duration or (overlay.mode != Overlay.Mode.NONE and overlay._t > 3.0):
		print("[autotest] fin. oleada=%d vidas=%d bajas=%d" % [Game.wave, Game.lives, Game.kills])
		get_tree().quit()

## Bot: construye siguiendo un plan con combos, mejora con el oro sobrante y adelanta oleadas.
func _bot_step() -> void:
	for step in BOT_PLAN:
		var key := Vector2i(step[0], step[1])
		if traps.has(key):
			continue
		if Game.gold >= Catalog.trap(step[2]).cost:
			_select(key)
			_build_trap(step[2])
		break
	if traps.size() >= 6 and Game.gold > 140:
		for t in traps.values():
			if t.level < Trap.MAX_LEVEL and Game.gold >= t.upgrade_cost() + 60:
				_select(Vector2i(t.floor_i, t.slot))
				_upgrade_selected()
				break
	_select(Vector2i(-1, -1))
	if _panel_test == "build":
		_select(Vector2i(3, 4))
	elif _panel_test == "trap" and not traps.is_empty():
		var t: Trap = traps.values()[0]
		_select(Vector2i(t.floor_i, t.slot))
	if director.idle() and director.countdown < _bot_wait():
		director.start_now()

func _bot_wait() -> float:
	return 9.0 if Game.wave < 3 else 6.0
