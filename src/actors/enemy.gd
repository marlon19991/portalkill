class_name Enemy
extends Node2D
## Enemigo que sigue la ruta en zigzag. Sin física: su posición es (piso, x).
## La lógica (estados, daño, desmembramiento) vive aquí; el aspecto en EnemyVisual.

const PARTS := [&"head", &"arm_f", &"arm_b", &"leg_f", &"leg_b"]
const TRANSIT := 0.45 ## segundos dentro del portal entre pisos

var data: EnemyData
var hp := 1.0
var max_hp := 1.0
var dead := false
var floor_i := 0
var spawning := 0.0   ## animación de salida del portal (intocable mientras > 0)
var transit := 0.0    ## dentro de un portal (invisible)
var facing := -1.0
var parts := {&"head": true, &"arm_f": true, &"arm_b": true, &"leg_f": true, &"leg_b": true}
var progress := 0.0   ## distancia total recorrida (para que las trampas prioricen al más avanzado)

# estados elementales (segundos restantes)
var burning := 0.0
var wet := 0.0
var oiled := 0.0
var stun := 0.0
var bleeding := 0.0
var shock_fx := 0.0
var char_amount := 0.0
var flash := 0.0

var walk_phase := 0.0
var hop := 0.0      ## altura visual sobre el suelo (rebote por golpes)
var _hop_v := 0.0
var _push := 0.0    ## empuje a lo largo de la ruta (negativo = hacia atrás)
var _speed_var := 1.0
var _fx_t := 0.0
var visual: EnemyVisual

func setup(d: EnemyData, wave: int) -> void:
	data = d
	max_hp = d.hp * (1.0 + (wave - 1) * 0.22)
	hp = max_hp
	_speed_var = Game.rng.randf_range(0.88, 1.12)
	visual = EnemyVisual.new()
	visual.enemy = self
	add_child(visual)
	_enter_floor(0)

func _enter_floor(f: int) -> void:
	floor_i = f
	facing = Tower.dir(f)
	position = Vector2(Tower.start_x(f), Tower.ground_y(f) - data.size.y * 0.5)
	spawning = 0.4
	visible = true

func center() -> Vector2:
	return position

func hit_rect() -> Rect2:
	return Rect2(position - data.size * 0.5, data.size)

func crawling() -> bool:
	return not parts[&"leg_f"] and not parts[&"leg_b"]

func on_ground() -> bool:
	return hop <= 0.0

func targetable() -> bool:
	return not dead and spawning <= 0.0 and transit <= 0.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	flash = maxf(0.0, flash - delta)
	shock_fx = maxf(0.0, shock_fx - delta)
	if transit > 0.0:
		transit -= delta
		if transit <= 0.0:
			_enter_floor(floor_i + 1)
			Game.fx.burst(position, 8, Color(1, 0.5, 0.15), 50.0)
		return
	if spawning > 0.0:
		spawning -= delta
	_tick_status(delta)
	if dead:
		return

	# avance por la ruta
	var spd := data.speed * _speed_var
	if crawling(): spd *= 0.35
	if wet > 0.0: spd *= 0.8
	if oiled > 0.0: spd *= 0.7
	if burning > 0.0: spd *= 1.35 # pánico: corren más
	if stun > 0.0: spd = 0.0
	_push = move_toward(_push, 0.0, 500.0 * delta)
	var step := (spd + _push) * delta
	position.x += facing * step
	progress += step
	# no retroceder más allá del portal de entrada
	var sx := Tower.start_x(floor_i)
	if (position.x - sx) * facing < 0.0:
		position.x = sx
	# rebote vertical (solo visual)
	if hop > 0.0 or _hop_v > 0.0:
		_hop_v -= 700.0 * delta
		hop = maxf(0.0, hop + _hop_v * delta)
		if hop <= 0.0:
			_hop_v = 0.0
			visual.squash = 0.2
	position.y = Tower.ground_y(floor_i) - data.size.y * 0.5 - hop
	walk_phase += spd * delta * 0.5

	# ¿llegó al final del piso?
	if (position.x - Tower.end_x(floor_i)) * facing >= 0.0:
		if floor_i < Tower.FLOORS - 1:
			transit = TRANSIT
			visible = false
			Game.fx.burst(position, 8, Color(1, 0.5, 0.15), 50.0)
		else:
			_leak()
			return
	visual.queue_redraw()

func _leak() -> void:
	dead = true
	Game.enemies.erase(self)
	Game.lives = maxi(0, Game.lives - data.lives_cost)
	Game.fx.burst(position, 20, Color(1, 0.15, 0.2), 90.0)
	Events.screen_shake.emit(0.35)
	Events.enemy_leaked.emit(self, data.lives_cost)
	queue_free()

func _tick_status(delta: float) -> void:
	stun = maxf(0.0, stun - delta)
	wet = maxf(0.0, wet - delta)
	oiled = maxf(0.0, oiled - delta)
	_fx_t -= delta
	var emit := _fx_t <= 0.0
	if emit:
		_fx_t = 0.05
	if burning > 0.0:
		burning -= delta
		char_amount = minf(1.0, char_amount + delta * 0.25)
		if oiled > 0.0:
			Elements.apply_hit(self, DamageInfo.make(0.0, DamageInfo.FIRE, Vector2.UP, 0.0))
			return
		if emit:
			Game.fx.flame(center() + Vector2(Game.rng.randf_range(-4, 4), Game.rng.randf_range(-6, 4)))
		# contagio a vecinos del mismo piso
		if Game.rng.randf() < delta * 2.0:
			for e in Game.enemies:
				if e != self and e.floor_i == floor_i and e.burning <= 0.0 and e.wet <= 0.0 and absf(e.position.x - position.x) < 12.0:
					e.burning = Elements.BURN_TIME * 0.7
		_damage_raw(7.0 * delta, DamageInfo.FIRE)
	if bleeding > 0.0:
		bleeding -= delta
		if emit and Game.gore > 0:
			Game.blood.drip(center() + Vector2(Game.rng.randf_range(-3, 3), 0), data.blood)
		_damage_raw(2.5 * delta, DamageInfo.CUT)
	if wet > 0.0 and emit and Game.rng.randf() < 0.3:
		Game.fx.drip(center() + Vector2(Game.rng.randf_range(-4, 4), data.size.y * 0.3), Color(0.4, 0.65, 1.0))

func _damage_raw(amount: float, element: int) -> void:
	hp -= amount
	if hp <= 0.0:
		die(DamageInfo.make(amount, element, Vector2.UP, 40.0))

func take_damage(amount: float, info: DamageInfo) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.07
	var kb := info.knockback * (1.0 - data.knockback_resist)
	if kb > 0.0:
		# empuje a lo largo de la ruta según la dirección del golpe
		_push += signf(info.dir.x) * facing * kb if absf(info.dir.x) > 0.1 else -kb
		if kb > 50.0 and hop <= 0.0:
			_hop_v = kb * 0.6
			hop = 0.01
	if info.dismember > 0.0 and Game.gore > 0 and Game.rng.randf() < info.dismember:
		_dismember(info)
	if hp <= 0.0:
		die(info)

func push_back(amount: float) -> void:
	_push -= amount * (1.0 - data.knockback_resist)

func _dismember(info: DamageInfo) -> void:
	var options: Array = []
	for k in PARTS:
		if parts[k] and k != &"head":
			options.append(k)
	if parts[&"head"] and (hp <= 0.0 or Game.rng.randf() < 0.12):
		options.append(&"head")
	if options.is_empty():
		return
	var part: StringName = options[Game.rng.randi() % options.size()]
	parts[part] = false
	var r := visual.part_rect(part)
	var pos := center() + r.get_center()
	Game.gibs.spawn(pos, info.dir * 100.0 + Vector2(Game.rng.randf_range(-50, 50), -150), r.size, _part_color(part), data.blood, part == &"head")
	Game.blood.burst(pos, info.dir, int(22 * Game.gore_mult()), data.blood)
	Events.screen_shake.emit(0.06)
	if part == &"head":
		hp = 0.0

func _part_color(part: StringName) -> Color:
	var c := data.skin if part == &"head" or String(part).begins_with("arm") else data.cloth
	return c.darkened(char_amount * 0.7)

func die(info: DamageInfo) -> void:
	if dead:
		return
	dead = true
	Game.kills += 1
	Game.enemies.erase(self)
	Game.add_gold(data.bounty)
	Game.fx.float_text("+%d" % data.bounty, center() + Vector2(0, -12), Color(1, 0.85, 0.3))
	Events.enemy_killed.emit(self, info)
	var c := center()
	var big := data.hp >= 100.0
	if Game.gore == Game.Gore.OFF:
		Game.fx.disintegrate(c, data.size, data.cloth)
	else:
		var force := info.dir * maxf(info.knockback, 60.0) * 1.2
		for k in PARTS:
			if parts[k]:
				var r := visual.part_rect(k)
				var v := force + Vector2(Game.rng.randf_range(-70, 70), Game.rng.randf_range(-190, -80))
				Game.gibs.spawn(c + r.get_center(), v, r.size, _part_color(k), data.blood, k == &"head")
		var torso := visual.part_rect(&"torso")
		var halves := 2 if info.amount > 14.0 or Game.gore == Game.Gore.EXTREME else 1
		for i in halves:
			var ts := Vector2(torso.size.x, torso.size.y / halves)
			Game.gibs.spawn(c + torso.get_center() + Vector2(0, (i - 0.5) * ts.y), force * 0.8 + Vector2(Game.rng.randf_range(-40, 40), -120), ts, data.cloth.darkened(char_amount * 0.7), data.blood)
		Game.blood.burst(c, info.dir, int((40 if big else 26) * Game.gore_mult()), data.blood)
	if data.death_effect == EnemyData.DeathEffect.OIL_BURST:
		Game.fx.add_oil_puddle(Vector2(c.x, Tower.ground_y(floor_i)), 60.0)
		Game.blood.burst(c, Vector2.UP, 30, Color(0.12, 0.1, 0.05))
		if burning > 0.0 or info.has(DamageInfo.FIRE):
			Elements.explode(c, 48.0, 30.0, DamageInfo.FIRE)
	Events.screen_shake.emit(0.3 if big else 0.08)
	if big:
		Events.hitstop.emit(0.05)
	queue_free()
