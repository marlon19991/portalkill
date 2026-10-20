class_name GibSystem
extends Node2D
## Pedazos de cuerpo con física propia sobre el grid (sin RigidBody2D).
## Al quedar quietos se pintan en el lienzo de sangre y se liberan: gore persistente gratis.

const MAX_GIBS := 160
const GRAVITY := 700.0

class Gib:
	var pos: Vector2
	var vel: Vector2
	var rot: float
	var rot_vel: float
	var size: Vector2
	var color: Color
	var blood: Color
	var head: bool
	var rest: float = 0.0
	var life: float = 7.0
	var bleed: float = 1.6

var gibs: Array[Gib] = []

func clear() -> void:
	gibs.clear()

func spawn(pos: Vector2, vel: Vector2, size: Vector2, color: Color, blood: Color, head: bool = false, _src: Node = null) -> void:
	if gibs.size() >= MAX_GIBS:
		_settle(gibs[0])
		gibs.remove_at(0)
	var g := Gib.new()
	g.pos = pos
	g.vel = vel
	g.rot = Game.rng.randf() * TAU
	g.rot_vel = Game.rng.randf_range(-14.0, 14.0)
	g.size = size.max(Vector2(2, 2))
	g.color = color
	g.blood = blood
	g.head = head
	gibs.append(g)

func _physics_process(delta: float) -> void:
	var level := Game.level
	var i := gibs.size() - 1
	while i >= 0:
		var g := gibs[i]
		g.vel.y = minf(g.vel.y + GRAVITY * delta, 450.0)
		g.life -= delta
		g.bleed -= delta
		var nx := g.pos + Vector2(g.vel.x * delta, 0)
		if level.is_wall(nx):
			g.vel.x *= -0.4
			g.rot_vel *= 0.6
		else:
			g.pos = nx
		var ny := g.pos + Vector2(0, g.vel.y * delta + g.size.y * 0.3 * signf(g.vel.y))
		if g.vel.y > 0.0 and level.is_solid(ny) or g.vel.y < 0.0 and level.is_wall(ny):
			if absf(g.vel.y) > 60.0 and g.bleed > 0.0:
				Game.blood.spray(g.pos, Vector2.UP, 3, g.blood)
			g.vel.y *= -0.3
			g.vel.x *= 0.7
			g.rot_vel *= 0.5
			if absf(g.vel.y) < 30.0:
				g.vel.y = 0.0
		else:
			g.pos.y += g.vel.y * delta
		g.rot += g.rot_vel * delta
		# rastro de sangre mientras vuela
		if g.bleed > 0.0 and g.vel.length_squared() > 900.0 and Game.rng.randf() < 0.5:
			Game.blood.drip(g.pos, g.blood)
		if g.vel.length_squared() < 25.0:
			g.rest += delta
		else:
			g.rest = 0.0
		if g.rest > 0.5 or g.life <= 0.0:
			_settle(g)
			gibs[i] = gibs[gibs.size() - 1]
			gibs.pop_back()
		i -= 1
	queue_redraw()

func _settle(g: Gib) -> void:
	Game.blood.stamp_gib(g.pos.round(), snappedf(g.rot, PI * 0.5), g.size, g.color)

func _draw() -> void:
	for g in gibs:
		draw_set_transform(g.pos.round(), g.rot, Vector2.ONE)
		var r := Rect2(-g.size * 0.5, g.size)
		draw_rect(r, g.color)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), g.color.lightened(0.15))
		# corte sangrante en un extremo
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - 1), Vector2(r.size.x, 1)), g.blood.lightened(0.1))
		if g.head:
			draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(1, 1)), Color(0.05, 0.0, 0.0))
		draw_set_transform(Vector2.ZERO)
