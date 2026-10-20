class_name Trap
extends Node2D
## Trampa colocada en una casilla. Comportamiento según TrapData.Behavior.
## Solo mira enemigos de su propio piso. Dibujo procedural reemplazable por sprites.

const MAX_LEVEL := 3

var data: TrapData
var floor_i := 0
var slot := 0
var level := 1
var invested := 0
var kills := 0
var _cd := 0.0
var _anim := 0.0     ## animación de activación (0..1)
var _active := 0.0   ## tiempo restante de efecto activo (lanzallamas, pisón)
var _spin := 0.0
var _blood := 0.0    ## suciedad acumulada (la sierra se mancha)
var _glow: GlowLayer

func setup(d: TrapData, f: int, s: int) -> void:
	data = d
	floor_i = f
	slot = s
	invested = d.cost
	position = Vector2(Tower.SLOT_X[s], Tower.ground_y(f) if d.mount == TrapData.Mount.FLOOR else Tower.ceiling_y(f))
	_cd = Game.rng.randf_range(0.0, d.cooldown)
	_glow = GlowLayer.new(_draw_glow)
	add_child(_glow)

func damage() -> float:
	return data.damage * pow(1.5, level - 1)

func cooldown() -> float:
	return data.cooldown * pow(0.85, level - 1)

func reach() -> float:
	return data.trap_range * (1.0 + 0.1 * (level - 1))

func upgrade_cost() -> int:
	return int(data.cost * 0.75 * level)

func sell_value() -> int:
	return int(invested * 0.6)

func upgrade() -> void:
	invested += upgrade_cost()
	level += 1
	Game.fx.burst(position + Vector2(0, _mount_dir() * 8.0), 14, data.color, 70.0)

func _mount_dir() -> float:
	return -1.0 if data.mount == TrapData.Mount.FLOOR else 1.0

## Enemigos del piso dentro del alcance horizontal, el más avanzado primero.
func _targets(r: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in Game.enemies:
		if e.floor_i == floor_i and e.targetable() and absf(e.position.x - position.x) <= r + e.data.size.x * 0.5:
			out.append(e)
	return out

func _best(r: float) -> Enemy:
	var best: Enemy = null
	for e in _targets(r):
		if best == null or e.progress > best.progress:
			best = e
	return best

func _hit(e: Enemy, amount: float, elements: int, kb: float = 0.0, dismember: float = 0.0) -> void:
	var dir := Vector2(signf(e.position.x - position.x), -0.3).normalized()
	if absf(e.position.x - position.x) < 2.0:
		dir = Vector2(-e.facing, -0.3).normalized()
	var was_alive := not e.dead
	Elements.apply_hit(e, DamageInfo.make(amount, elements, dir, kb, dismember))
	if was_alive and e.dead:
		kills += 1

func _physics_process(delta: float) -> void:
	_cd -= delta
	_anim = maxf(0.0, _anim - delta * 4.0)
	_active = maxf(0.0, _active - delta)
	match data.behavior:
		TrapData.Behavior.SAW: _saw(delta)
		TrapData.Behavior.FLAME: _flame(delta)
		TrapData.Behavior.TESLA: _tesla()
		TrapData.Behavior.SPRINKLER: _sprinkler(delta)
		TrapData.Behavior.OIL: _oil()
		TrapData.Behavior.TURRET: _turret()
		TrapData.Behavior.PISTON: _piston()
	queue_redraw()
	_glow.queue_redraw()

func _saw(delta: float) -> void:
	var t := _targets(reach())
	_spin += delta * (26.0 if not t.is_empty() else 12.0)
	if _cd > 0.0 or t.is_empty():
		return
	_cd = cooldown()
	for e in t:
		_hit(e, damage(), data.elements, 0.0, data.dismember + 0.02 * level)
		Game.blood.spray(position + Vector2(0, -6), Vector2(-e.facing, -1.2).normalized(), 4, e.data.blood)
		_blood = minf(1.0, _blood + 0.02)
	Game.fx.sparks(position + Vector2(0, -8), 1, Color(1, 0.9, 0.6))

func _flame(delta: float) -> void:
	if _active > 0.0:
		for i in 3:
			Game.fx.flame(position + Vector2(Game.rng.randf_range(-reach() * 0.6, reach() * 0.6), -Game.rng.randf_range(2.0, 30.0)))
		if Game.rng.randf() < delta * 10.0:
			for e in _targets(reach()):
				_hit(e, damage(), data.elements)
		return
	if _cd <= 0.0 and not _targets(reach() + 18.0).is_empty():
		_cd = cooldown() + 1.0
		_active = 1.0
		_anim = 1.0
		Events.screen_shake.emit(0.05)

func _tesla() -> void:
	if _cd > 0.0:
		return
	var e := _best(reach())
	if e == null:
		return
	_cd = cooldown()
	_anim = 1.0
	var tip := position + Vector2(0, 20)
	Game.fx.lightning(tip, e.center(), data.color)
	var bonus := 2 if e.wet > 0.0 else 0
	_hit(e, damage(), data.elements, 20.0)
	Elements.chain_from(e, data.chain_count + level - 1 + bonus, damage() * 0.85, 60.0, data.color)

func _sprinkler(delta: float) -> void:
	var r := reach()
	if Game.rng.randf() < delta * 30.0:
		Game.fx.part(position + Vector2(Game.rng.randf_range(-3, 3), 8), Vector2(Game.rng.randf_range(-r, r) * 1.2, 30.0), 0.9, Color(0.4, 0.65, 1.0, 0.8), 1.0, 160.0)
	if _cd > 0.0:
		return
	_cd = cooldown()
	for e in _targets(r):
		_hit(e, 0.0, data.elements)

func _oil() -> void:
	if _cd > 0.0:
		return
	_cd = cooldown()
	_anim = 1.0
	var ground := Vector2(position.x, Tower.ground_y(floor_i))
	Game.fx.add_oil_puddle(ground, reach() * 2.0)
	for i in 8:
		Game.fx.part(position + Vector2(Game.rng.randf_range(-2, 2), 10), Vector2(Game.rng.randf_range(-15, 15), 60.0), 1.2, Color(0.12, 0.1, 0.05), 2.0, 300.0)

func _turret() -> void:
	if _cd > 0.0:
		return
	var e := _best(reach())
	if e == null:
		return
	_cd = cooldown()
	_anim = 1.0
	var muzzle := position + Vector2(0, -9)
	var dir := (e.center() - muzzle).normalized()
	var info := DamageInfo.make(damage(), data.elements, dir, data.knockback)
	Game.projectiles.spawn(muzzle + dir * 8.0, dir * 420.0, ProjectileSystem.Kind.BULLET, info, data.color, 0.0, level - 1, 0.6)
	Game.fx.muzzle(muzzle + dir * 8.0, dir, data.color, false)
	Game.fx.shell(muzzle, dir)
	_spin = dir.angle()

func _piston() -> void:
	if _cd > 0.0 or _targets(reach()).is_empty():
		return
	_cd = cooldown()
	_active = 0.35
	_anim = 1.0
	var t := _targets(reach())
	for e in t:
		_hit(e, damage(), data.elements, 0.0, data.dismember)
		if not e.dead:
			e.push_back(data.knockback)
			e.stun = maxf(e.stun, 0.3)
		Game.blood.burst(e.center(), Vector2.UP, int(10 * Game.gore_mult()), e.data.blood)
	Game.fx.dust(Vector2(position.x, Tower.ground_y(floor_i)), 10)
	Events.screen_shake.emit(0.18)
	if not t.is_empty():
		Events.hitstop.emit(0.03)

# ---------------------------------------------------------------- dibujo

func _pips(y: float) -> void:
	for i in level:
		draw_rect(Rect2(-4 + i * 3, y, 2, 2), Color(1, 0.85, 0.3))

func _draw() -> void:
	var c := data.color.lightened(0.1 * (level - 1))
	var metal := Color(0.32, 0.33, 0.38)
	match data.behavior:
		TrapData.Behavior.SAW:
			# hoja semienterrada que gira
			var r := 8.0 + level
			var blade := c.lerp(Color(0.55, 0.05, 0.07), _blood * 0.7)
			draw_circle(Vector2(0, 0), r, blade.darkened(0.25))
			for i in 8:
				var a := _spin + i * TAU / 8.0
				draw_rect(Rect2(Vector2(cos(a), sin(a)) * r - Vector2(1, 1), Vector2(3, 3)), blade)
			draw_circle(Vector2.ZERO, 2.0, metal)
			draw_rect(Rect2(-12, -1, 24, 3), metal.darkened(0.3))
			draw_rect(Rect2(-12, -1, 24, 1), metal)
			_pips(4)
		TrapData.Behavior.FLAME:
			draw_rect(Rect2(-9, -3, 18, 3), metal)
			for i in 4:
				draw_rect(Rect2(-7 + i * 4, -3, 2, 1), Color(0.1, 0.08, 0.08))
			draw_rect(Rect2(-9, -3, 18, 1), metal.lightened(0.2))
			var heat := 1.0 if _active > 0.0 else clampf(1.0 - _cd / cooldown(), 0.0, 1.0) * 0.4
			draw_rect(Rect2(-5, -2, 10, 1), Color(1, 0.4, 0.1, heat))
			_pips(2)
		TrapData.Behavior.TESLA:
			draw_rect(Rect2(-5, 0, 10, 3), metal.darkened(0.2))
			draw_rect(Rect2(-2, 3, 4, 12), metal)
			for i in 4:
				draw_rect(Rect2(-4, 5 + i * 3, 8, 1), Color(0.75, 0.45, 0.2))
			draw_circle(Vector2(0, 18), 3.0 + _anim, c)
			_pips(-3)
		TrapData.Behavior.SPRINKLER:
			draw_rect(Rect2(-1, 0, 2, 6), metal)
			draw_rect(Rect2(-5, 6, 10, 2), metal.lightened(0.15))
			draw_rect(Rect2(-4, 8, 8, 1), c)
			_pips(-3)
		TrapData.Behavior.OIL:
			draw_rect(Rect2(-8, 0, 16, 4), Color(0.25, 0.22, 0.15))
			draw_rect(Rect2(-6, 4, 12, 8), Color(0.35, 0.28, 0.15))
			draw_rect(Rect2(-6, 7, 12, 1), Color(0.2, 0.15, 0.08))
			draw_rect(Rect2(-1, 12, 2, 2 + _anim * 3.0), Color(0.08, 0.07, 0.04))
			_pips(-3)
		TrapData.Behavior.TURRET:
			draw_rect(Rect2(-6, -6, 12, 6), metal.darkened(0.2))
			draw_rect(Rect2(-4, -10, 8, 5), metal)
			draw_set_transform(Vector2(0, -9), _spin, Vector2.ONE)
			draw_rect(Rect2(0 - _anim * 2.0, -1, 9, 2), c.darkened(0.3))
			draw_rect(Rect2(7 - _anim * 2.0, -1, 2, 2), c)
			draw_set_transform(Vector2.ZERO)
			_pips(1)
		TrapData.Behavior.PISTON:
			var reach_y := Tower.FLOOR_H - Tower.SLAB - 8.0
			var ext := reach_y * (_active / 0.35 if _active > 0.0 else 0.0)
			ext = reach_y if _active > 0.2 else ext
			draw_rect(Rect2(-8, 0, 16, 5), metal.darkened(0.2))
			draw_rect(Rect2(-2, 5, 4, maxf(4.0, ext - 6.0)), metal.lightened(0.1))
			var head_y := maxf(9.0, ext)
			draw_rect(Rect2(-10, head_y - 6, 20, 6), c.darkened(0.2))
			draw_rect(Rect2(-10, head_y - 1, 20, 1), Color(0.5, 0.05, 0.05) if kills > 0 else c.darkened(0.5))
			_pips(-3)

func _draw_glow(ci: Node2D) -> void:
	match data.behavior:
		TrapData.Behavior.TESLA:
			Pixel.glow(ci, Vector2(0, 18), 10.0 + _anim * 14.0, Color(data.color, 0.35 + _anim * 0.4))
		TrapData.Behavior.FLAME:
			if _active > 0.0:
				Pixel.glow(ci, Vector2(0, -14), 34.0, Color(1, 0.45, 0.1, 0.5))
		TrapData.Behavior.TURRET:
			if _anim > 0.0:
				Pixel.glow(ci, Vector2(0, -9) + Vector2.from_angle(_spin) * 9.0, 8.0, Color(data.color, _anim * 0.6))
