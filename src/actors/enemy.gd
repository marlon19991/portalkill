class_name Enemy
extends CharacterBody2D
## Enemigo genérico guiado por EnemyData. La lógica (IA, estados, daño) vive aquí;
## el aspecto vive en EnemyVisual, intercambiable por sprites más adelante.

const GRAVITY := 900.0
const PARTS := [&"head", &"arm_f", &"arm_b", &"leg_f", &"leg_b"]

var data: EnemyData
var hp := 1.0
var dead := false
var spawning := 0.0
var facing := 1.0
var parts := {&"head": true, &"arm_f": true, &"arm_b": true, &"leg_f": true, &"leg_b": true}

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
var _speed_var := 1.0
var _x_bias := 0.0
var _jump_cd := 0.0
var _attack_cd := 0.0
var _drop_t := 0.0
var _panic_t := 0.0
var _panic_dir := 1.0
var _fx_t := 0.0
var _ledge_dir := 0.0
var _ledge_t := 0.0
var visual: EnemyVisual

func setup(d: EnemyData, pos: Vector2) -> void:
	data = d
	hp = d.hp * (1.0 + Game.floor_index * 0.12)
	global_position = pos
	spawning = 0.55
	_speed_var = Game.rng.randf_range(0.85, 1.15)
	_x_bias = Game.rng.randf_range(-10.0, 10.0)
	velocity = Vector2(Game.rng.randf_range(-60.0, 60.0), Game.rng.randf_range(-40.0, 0.0))
	collision_layer = 8
	collision_mask = 1 | 2
	floor_snap_length = 3.0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = d.size
	cs.shape = sh
	add_child(cs)
	visual = EnemyVisual.new()
	visual.enemy = self
	add_child(visual)

func center() -> Vector2:
	return global_position

func hit_rect() -> Rect2:
	return Rect2(global_position - data.size * 0.5, data.size)

func crawling() -> bool:
	return not parts[&"leg_f"] and not parts[&"leg_b"]

func _physics_process(delta: float) -> void:
	if dead:
		return
	flash = maxf(0.0, flash - delta)
	shock_fx = maxf(0.0, shock_fx - delta)
	_jump_cd -= delta
	_attack_cd -= delta
	if spawning > 0.0:
		spawning -= delta
		velocity *= 0.92
		global_position += velocity * delta
		visual.queue_redraw()
		return
	_tick_status(delta)
	if dead:
		return
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0:
			set_collision_mask_value(2, true)

	velocity.y = minf(velocity.y + GRAVITY * delta, 500.0)
	var p := Game.player
	if stun > 0.0 or p == null:
		velocity.x = move_toward(velocity.x, 0.0, data.accel * delta)
	else:
		_ai(p, delta)
	move_and_slide()
	walk_phase += absf(velocity.x) * delta * 0.22

	# ataque por contacto
	if p and not p.dead and stun <= 0.0 and _attack_cd <= 0.0 and hit_rect().intersects(p.hit_rect()):
		p.hurt(data.contact_damage, Vector2(signf(p.center().x - center().x), -0.4).normalized())
		_attack_cd = 0.9
	visual.queue_redraw()

func _ai(p: Player, delta: float) -> void:
	var dx := p.center().x + _x_bias - center().x
	var dy := p.center().y - center().y
	var dir := signf(dx) if absf(dx) > 4.0 else 0.0
	# jugador debajo y estoy sobre suelo sólido: caminar hacia el borde más cercano
	_ledge_t -= delta
	if dy > 26.0 and is_on_floor() and absf(dx) < 120.0:
		if _ledge_t <= 0.0:
			_ledge_t = 1.0
			_ledge_dir = _find_ledge()
		if _ledge_dir != 0.0:
			dir = _ledge_dir
	var spd := data.speed * _speed_var
	if crawling():
		spd *= 0.35
	if burning > 0.0:
		# pánico: corre erráticamente
		_panic_t -= delta
		if _panic_t <= 0.0:
			_panic_t = Game.rng.randf_range(0.3, 0.8)
			_panic_dir = -1.0 if Game.rng.randf() < 0.5 else 1.0
		dir = _panic_dir
		spd *= 1.3
	if dir != 0.0:
		facing = dir
	velocity.x = move_toward(velocity.x, dir * spd, data.accel * delta)
	if is_on_floor():
		if _jump_cd <= 0.0 and not crawling():
			if is_on_wall() and absf(dx) > 8.0:
				_jump()
			elif dy < -26.0 and absf(dx) < 90.0 and Game.rng.randf() < 0.06:
				_jump()
		if dy > 26.0 and _drop_t <= 0.0:
			var feet := center() + Vector2(0, data.size.y * 0.5 + 2.0)
			if Game.level.cell(int(feet.x / Level.TILE), int(feet.y / Level.TILE)) == Level.ONEWAY and Game.rng.randf() < 0.05:
				set_collision_mask_value(2, false)
				_drop_t = 0.3

## Busca a izquierda y derecha el borde más cercano por donde dejarse caer.
func _find_ledge() -> float:
	var lv := Game.level
	var fx := int(center().x / Level.TILE)
	var fy := int((center().y + data.size.y * 0.5 + 2.0) / Level.TILE)
	if lv.cell(fx, fy) != Level.SOLID:
		return 0.0
	for d in range(1, 16):
		for s in [-1, 1]:
			var c := lv.cell(fx + d * s, fy)
			if c != Level.SOLID:
				return float(s)
	return 0.0

func _jump() -> void:
	velocity.y = -data.jump_force * Game.rng.randf_range(0.9, 1.05)
	_jump_cd = Game.rng.randf_range(0.5, 1.2)
	visual.squash = -0.25

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
		# contagio a vecinos
		if Game.rng.randf() < delta * 2.0:
			for e in Game.enemies:
				if e != self and e.burning <= 0.0 and e.wet <= 0.0 and e.center().distance_squared_to(center()) < 196.0:
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
	velocity += info.dir * kb
	if kb > 60.0:
		velocity.y = minf(velocity.y, -kb * 0.35)
	if info.dismember > 0.0 and Game.gore > 0 and Game.rng.randf() < info.dismember:
		_dismember(info)
	if hp <= 0.0:
		die(info)

func _dismember(info: DamageInfo) -> void:
	var options: Array = []
	for k in PARTS:
		if parts[k] and k != &"head":
			options.append(k)
	# la cabeza solo sale en golpes letales o con suerte
	if parts[&"head"] and (hp <= 0.0 or Game.rng.randf() < 0.12):
		options.append(&"head")
	if options.is_empty():
		return
	var part: StringName = options[Game.rng.randi() % options.size()]
	parts[part] = false
	var r := visual.part_rect(part)
	var pos := center() + r.get_center()
	Game.gibs.spawn(pos, info.dir * 140.0 + Vector2(Game.rng.randf_range(-40, 40), -120), r.size, _part_color(part), data.blood, part == &"head", self)
	Game.blood.burst(pos, info.dir, int(22 * Game.gore_mult()), data.blood)
	Events.screen_shake.emit(0.08)
	if part == &"head":
		hp = 0.0

func _part_color(part: StringName) -> Color:
	var c := data.skin if part == &"head" or part.begins_with("arm") else data.cloth
	return c.darkened(char_amount * 0.7)

func die(info: DamageInfo) -> void:
	if dead:
		return
	dead = true
	Game.kills += 1
	Game.enemies.erase(self)
	Events.enemy_killed.emit(self, info)
	var c := center()
	var big := data.hp >= 100.0
	if Game.gore == Game.Gore.OFF:
		Game.fx.disintegrate(c, data.size, data.cloth)
	else:
		var force := info.dir * maxf(info.knockback, 60.0) * 1.4
		for k in PARTS:
			if parts[k]:
				var r := visual.part_rect(k)
				var v := force + Vector2(Game.rng.randf_range(-70, 70), Game.rng.randf_range(-170, -60))
				Game.gibs.spawn(c + r.get_center(), v, r.size, _part_color(k), data.blood, k == &"head", self)
		# torso partido en dos en golpes fuertes
		var torso := visual.part_rect(&"torso")
		var halves := 2 if info.amount > 14.0 or Game.gore == Game.Gore.EXTREME else 1
		for i in halves:
			var ts := Vector2(torso.size.x, torso.size.y / halves)
			Game.gibs.spawn(c + torso.get_center() + Vector2(0, (i - 0.5) * ts.y), force * 0.8 + Vector2(Game.rng.randf_range(-40, 40), -100), ts, data.cloth.darkened(char_amount * 0.7), data.blood, false, self)
		Game.blood.burst(c, info.dir, int((40 if big else 26) * Game.gore_mult()), data.blood)
	if data.death_effect == EnemyData.DeathEffect.OIL_BURST:
		Game.fx.add_oil_puddle(Game.level.ground_below(c), 64.0)
		Game.blood.burst(c, Vector2.UP, 30, Color(0.12, 0.1, 0.05))
		if burning > 0.0 or info.has(DamageInfo.FIRE):
			Elements.explode(c, 52.0, 30.0, DamageInfo.FIRE)
	Events.screen_shake.emit(0.35 if big else 0.12)
	if big:
		Events.hitstop.emit(0.06)
	queue_free()
