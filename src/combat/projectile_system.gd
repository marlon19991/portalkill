class_name ProjectileSystem
extends Node2D
## Todas las balas viven en un array y se dibujan en un único _draw.
## Sin nodos ni física por bala: colisión con el grid (O(1)) y con rectángulos de enemigos.

enum Kind { BULLET, MOLOTOV, WATER }

class Bullet:
	var pos: Vector2
	var prev: Vector2
	var vel: Vector2
	var life: float
	var gravity: float
	var kind: int
	var info: DamageInfo
	var pierce: int
	var color: Color
	var hit: Array = []
	var spin: float = 0.0

const MAX_BULLETS := 600
const STEP := 4.0

var bullets: Array[Bullet] = []
var _glow: GlowLayer

func _ready() -> void:
	_glow = GlowLayer.new(_draw_glow)
	add_child(_glow)

func clear() -> void:
	bullets.clear()

func spawn(pos: Vector2, vel: Vector2, kind: int, info: DamageInfo, color: Color, gravity: float = 0.0, pierce: int = 0, life: float = 1.6) -> void:
	if bullets.size() >= MAX_BULLETS:
		return
	var b := Bullet.new()
	b.pos = pos
	b.prev = pos
	b.vel = vel
	b.kind = kind
	b.info = info
	b.color = color
	b.gravity = gravity
	b.pierce = pierce
	b.life = life
	bullets.append(b)

func _physics_process(delta: float) -> void:
	var level := Game.level
	var i := bullets.size() - 1
	while i >= 0:
		var b := bullets[i]
		b.prev = b.pos
		b.vel.y += b.gravity * delta
		b.life -= delta
		b.spin += delta * 14.0
		var alive := b.life > 0.0
		# sub-pasos para no atravesar paredes delgadas
		var move := b.vel * delta
		var steps := maxi(1, int(ceilf(move.length() / STEP)))
		var step := move / steps
		for s in steps:
			if not alive:
				break
			b.pos += step
			if level.is_wall(b.pos) or (b.kind != Kind.BULLET and level.is_solid(b.pos)):
				_impact_world(b)
				alive = false
				break
			var e := _hit_enemy(b)
			if e:
				_impact_enemy(b, e)
				if b.kind != Kind.BULLET or b.pierce < 0:
					alive = false
					break
		if not alive:
			bullets[i] = bullets[bullets.size() - 1]
			bullets.pop_back()
		i -= 1
	queue_redraw()
	_glow.queue_redraw()

func _hit_enemy(b: Bullet) -> Enemy:
	for e in Game.enemies:
		if e.dead or e.spawning > 0.0 or b.hit.has(e):
			continue
		if e.hit_rect().grow(1.0 if b.kind == Kind.BULLET else 2.0).has_point(b.pos):
			return e
	return null

func _impact_enemy(b: Bullet, e: Enemy) -> void:
	b.hit.append(e)
	var info := b.info.copy()
	info.dir = b.vel.normalized()
	match b.kind:
		Kind.MOLOTOV:
			_molotov_break(b)
			Elements.apply_hit(e, info)
		Kind.WATER:
			Elements.apply_hit(e, info)
			Game.fx.splash(b.pos, b.color, 3)
		_:
			Elements.apply_hit(e, info)
			Game.blood.spray(b.pos, info.dir, 5, e.data.blood)
			# infusión eléctrica: mini-cadena
			if info.has(DamageInfo.ELECTRIC):
				Weapons.chain_from(e, 1, info.amount * 0.6, 60.0)
			b.pierce -= 1

func _impact_world(b: Bullet) -> void:
	match b.kind:
		Kind.MOLOTOV:
			_molotov_break(b)
		Kind.WATER:
			Game.fx.splash(b.prev, b.color, 2)
		_:
			Game.fx.sparks(b.prev, 4, b.color)

func _molotov_break(b: Bullet) -> void:
	Game.fx.sparks(b.pos, 8, Color(0.8, 0.9, 1.0))
	Game.fx.burst(b.pos, 16, Color(1, 0.6, 0.15), 90.0)
	Events.screen_shake.emit(0.18)
	var ground := Game.level.ground_below(b.prev, 120.0)
	Game.fx.add_fire_zone(ground, 46.0, 4.5)
	for e: Enemy in Game.enemies.duplicate():
		if e.center().distance_to(b.pos) < 26.0:
			Elements.apply_hit(e, DamageInfo.make(b.info.amount, b.info.elements, (e.center() - b.pos).normalized(), 40.0))

func _draw() -> void:
	for b in bullets:
		match b.kind:
			Kind.MOLOTOV:
				draw_set_transform(b.pos, b.spin, Vector2.ONE)
				draw_rect(Rect2(-2, -3, 4, 5), Color(0.35, 0.55, 0.3))
				draw_rect(Rect2(-1, -5, 2, 2), Color(0.8, 0.75, 0.6))
				draw_rect(Rect2(-1, -6, 2, 1), Color(1, 0.6, 0.1))
				draw_set_transform(Vector2.ZERO)
			Kind.WATER:
				draw_rect(Rect2(b.pos.round() - Vector2(1, 1), Vector2(2, 2)), b.color)
			_:
				var tail := b.pos - b.vel.normalized() * 6.0
				draw_line(tail.round(), b.pos.round(), b.color.darkened(0.3), 1.0)
				draw_rect(Rect2(b.pos.round() - Vector2(1, 0), Vector2(2, 1)), Color(1, 1, 0.9))

func _draw_glow(ci: Node2D) -> void:
	for b in bullets:
		match b.kind:
			Kind.MOLOTOV:
				Pixel.glow(ci, b.pos + Vector2(0, -5).rotated(b.spin), 10.0, Color(1, 0.5, 0.1, 0.6))
			Kind.WATER:
				pass
			_:
				Pixel.glow(ci, b.pos, 7.0, Color(b.color, 0.5))
