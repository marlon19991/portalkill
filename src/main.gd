extends Node2D
## Orquestador: arma el mundo, encadena pisos → oleadas → portal → recompensa,
## y gestiona cámara (shake), hitstop, pausa, game over y el modo autotest.

var level: Level
var player: Player
var director: WaveDirector
var entry: Portal
var exit_portal: Portal
var enemies_root: Node2D
var camera: Camera2D
var hud: Hud
var reward: RewardScreen
var overlay: Overlay
var world: Node2D

var _trauma := 0.0
var _hitstop_until := 0
var _noise := FastNoiseLite.new()
var _time := 0.0
var _base_scale := 1.0
var _last_us := 0

# autotest
var _shots: Array = [2.5, 8.0, 15.0, 24.0, 34.0, 46.0]
var _shot_dir := ""
var _duration := 60.0
var _stat_t := 0.0
var _fps_samples: Array[float] = []

func _ready() -> void:
	var f := ThemeDB.fallback_font
	if f is FontFile:
		(f as FontFile).antialiasing = TextServer.FONT_ANTIALIASING_NONE
		(f as FontFile).hinting = TextServer.HINTING_NONE
	_build()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_shot_dir = a.trim_prefix("--shots=")
		if a.begins_with("--duration="):
			_duration = float(a.trim_prefix("--duration="))
		if a.begins_with("--timescale="):
			_base_scale = float(a.trim_prefix("--timescale="))
			Engine.time_scale = _base_scale
		if a.begins_with("--shotevery="):
			var every := float(a.trim_prefix("--shotevery="))
			_shots.clear()
			var t := every
			while t < 1000.0:
				_shots.append(t)
				t += every
		if a == "--stress":
			Game.stress = true
		if a.begins_with("--gore="):
			Game.gore = int(a.trim_prefix("--gore="))
	if Game.autotest:
		player.god = true
	_new_run()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--startfloor="):
			# demo: arranca más adelante con el arsenal completo
			for id in [&"shotgun", &"molotov", &"taser", &"hydro"]:
				player.add_weapon(Catalog.weapon(id))
			_start_floor(int(a.trim_prefix("--startfloor=")))

func _build() -> void:
	world = Node2D.new()
	add_child(world)
	level = Level.new()
	world.add_child(level)
	Game.level = level

	var blood := BloodSystem.new()
	blood.z_index = 5
	world.add_child(blood)
	Game.blood = blood

	entry = Portal.new()
	entry.z_index = 2
	world.add_child(entry)
	exit_portal = Portal.new()
	exit_portal.z_index = 2
	world.add_child(exit_portal)
	exit_portal.entered.connect(_on_exit_entered)

	enemies_root = Node2D.new()
	enemies_root.z_index = 3
	world.add_child(enemies_root)

	var gibs := GibSystem.new()
	gibs.z_index = 4
	world.add_child(gibs)
	Game.gibs = gibs

	player = Player.new()
	player.z_index = 4
	world.add_child(player)
	Game.player = player

	var proj := ProjectileSystem.new()
	proj.z_index = 6
	world.add_child(proj)
	Game.projectiles = proj

	var fx := FxSystem.new()
	fx.z_index = 7
	world.add_child(fx)
	Game.fx = fx

	camera = Camera2D.new()
	camera.position = Vector2(320, 188) # suelo completo visible; el techo queda a medias
	add_child(camera)
	camera.make_current()

	director = WaveDirector.new()
	add_child(director)
	director.spawn_requested.connect(_spawn_enemy)
	director.all_waves_cleared.connect(_on_cleared)

	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	reward = RewardScreen.new()
	ui.add_child(reward)
	reward.chosen.connect(_on_reward_chosen)
	overlay = Overlay.new()
	ui.add_child(overlay)

	_noise.frequency = 0.9
	Events.screen_shake.connect(func(t: float) -> void: _trauma = minf(1.0, _trauma + t))
	Events.hitstop.connect(_on_hitstop)
	Events.player_died.connect(_on_player_died)
	process_mode = Node.PROCESS_MODE_ALWAYS
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	director.process_mode = Node.PROCESS_MODE_PAUSABLE

func _new_run() -> void:
	Game.reset_run()
	player.reset_loadout()
	player.visible = true
	overlay.show_mode(Overlay.Mode.NONE)
	_start_floor(0)

func _start_floor(i: int) -> void:
	Game.floor_index = i
	Game.exit_open = false
	for e in Game.enemies:
		e.queue_free()
	Game.enemies.clear()
	Game.projectiles.clear()
	Game.fx.clear()
	Game.gibs.clear()
	Game.blood.clear()
	var n := Layouts.FLOORS.size()
	var theme: Dictionary = Layouts.THEMES[i % Layouts.THEMES.size()]
	level.build(Layouts.FLOORS[i % n], theme)
	entry.setup(false, theme.accent)
	entry.position = level.entry_pos
	exit_portal.setup(true, theme.accent)
	exit_portal.position = level.exit_pos
	player.global_position = level.spawn_pos
	player.velocity = Vector2.ZERO
	player.visible = true
	director.start(i)
	Events.floor_started.emit(i)

func _spawn_enemy(d: EnemyData) -> void:
	var e := Enemy.new()
	e.setup(d, entry.global_position + Vector2(Game.rng.randf_range(-4, 4), Game.rng.randf_range(-6, 6)))
	enemies_root.add_child(e)
	Game.enemies.append(e)
	entry.pulse()
	Game.fx.burst(entry.global_position, 6, Color(1, 0.2, 0.4), 60.0)
	Events.enemy_spawned.emit(e)

func _on_cleared() -> void:
	Game.exit_open = true
	exit_portal.set_open(true)
	Events.floor_cleared.emit()

func _on_exit_entered() -> void:
	player.visible = false
	Game.fx.burst(player.center(), 40, exit_portal.color, 160.0)
	Events.screen_shake.emit(0.4)
	await get_tree().create_timer(0.5).timeout
	get_tree().paused = true
	reward.open(player)

func _on_reward_chosen() -> void:
	get_tree().paused = false
	_start_floor(Game.floor_index + 1)

func _on_player_died() -> void:
	Events.screen_shake.emit(1.0)
	director.stop()
	await get_tree().create_timer(1.0).timeout
	overlay.show_mode(Overlay.Mode.GAMEOVER)

func _on_hitstop(d: float) -> void:
	var until := Time.get_ticks_msec() + int(d * 1000.0)
	if until > _hitstop_until:
		_hitstop_until = until
	Engine.time_scale = _base_scale * 0.05

func _process(_delta: float) -> void:
	# tiempo real medido con el reloj (no depende de time_scale ni del hitstop)
	var now := Time.get_ticks_usec()
	var real := 0.016 if _last_us == 0 else (now - _last_us) / 1000000.0
	_last_us = now
	if Engine.time_scale < _base_scale and Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = _base_scale
	_time += real * (_base_scale if Game.autotest else 1.0)
	# screen shake con ruido (trauma²), redondeado a píxeles
	_trauma = maxf(0.0, _trauma - real * 1.6)
	var s := _trauma * _trauma
	camera.offset = Vector2(_noise.get_noise_2d(_time * 60.0, 0.0), _noise.get_noise_2d(0.0, _time * 60.0)) * 7.0 * s
	camera.offset = camera.offset.round()
	camera.rotation = _noise.get_noise_2d(_time * 40.0, 99.0) * 0.02 * s
	if Game.autotest:
		_autotest(real)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		hud.debug = not hud.debug
	elif event.is_action_pressed("toggle_gore"):
		Game.gore = (Game.gore + 1) % 3
		hud.show_banner("GORE: %s" % ["APAGADO", "NORMAL", "EXTREMO"][Game.gore], Color(1, 0.3, 0.3))
		overlay.queue_redraw()
	elif event.is_action_pressed("pause") and not reward.visible and overlay.mode != Overlay.Mode.GAMEOVER:
		var p := not get_tree().paused
		get_tree().paused = p
		overlay.show_mode(Overlay.Mode.PAUSE if p else Overlay.Mode.NONE)
	elif event.is_action_pressed("restart") and overlay.mode == Overlay.Mode.GAMEOVER:
		get_tree().paused = false
		_new_run()

func _autotest(real: float) -> void:
	var delta := real * _base_scale # tiempo de juego, no de reloj
	_stat_t += delta
	_fps_samples.append(1.0 / maxf(real, 0.0001))
	if _stat_t >= 2.0:
		_stat_t = 0.0
		var avg := 0.0
		var mn := INF
		for v in _fps_samples:
			avg += v
			mn = minf(mn, v)
		avg /= maxf(1.0, _fps_samples.size())
		_fps_samples.clear()
		print("[autotest] t=%.0f piso=%d fps_avg=%.0f fps_min=%.0f enemigos=%d balas=%d sangre=%d gibs=%d fx=%d bajas=%d" % [
			_time, Game.floor_index + 1, avg, mn, Game.enemies.size(), Game.projectiles.bullets.size(),
			Game.blood.count(), Game.gibs.gibs.size(), Game.fx.count(), Game.kills])
	if not _shots.is_empty() and _time >= _shots[0]:
		_shots.pop_front()
		if _shot_dir != "":
			var img := get_viewport().get_texture().get_image()
			var path := "%s/shot_%02d.png" % [_shot_dir, int(_time)]
			img.save_png(path)
			print("[autotest] captura ", path)
	if _time >= _duration:
		print("[autotest] fin. bajas=%d piso=%d" % [Game.kills, Game.floor_index + 1])
		get_tree().quit()
