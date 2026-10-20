class_name FxSystem
extends Node2D
## Efectos visuales y zonas de suelo (fuego, aceite) en arrays, dibujados en 2 capas:
## normal (este nodo) y aditiva (GlowLayer). Sin nodos por partícula.

const MAX_PARTS := 2600

class Zone:
	var pos: Vector2
	var half: float
	var life: float
	var oil: bool
	var tick: float = 0.0

class Arc:
	var a: Vector2
	var b: Vector2
	var life: float
	var color: Color

class Slash:
	var origin: Vector2
	var dir: Vector2
	var reach: float
	var life: float
	var color: Color

class Boom:
	var pos: Vector2
	var radius: float
	var life: float

class FText:
	var text: String
	var pos: Vector2
	var life: float
	var color: Color

# partículas (structure of arrays)
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _max := PackedFloat32Array()
var _col := PackedColorArray()
var _size := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _add := PackedByteArray()

var zones: Array[Zone] = []
var _arcs: Array[Arc] = []
var _slashes: Array[Slash] = []
var _booms: Array[Boom] = []
var _texts: Array[FText] = []
var _glow: GlowLayer
var _font: Font

func _ready() -> void:
	_glow = GlowLayer.new(_draw_glow)
	add_child(_glow)
	_font = ThemeDB.fallback_font

func clear() -> void:
	_pos.clear(); _vel.clear(); _life.clear(); _max.clear(); _col.clear(); _size.clear(); _grav.clear(); _add.clear()
	zones.clear(); _arcs.clear(); _slashes.clear(); _booms.clear(); _texts.clear()

func count() -> int:
	return _pos.size()

func part(p: Vector2, v: Vector2, life: float, c: Color, size: float = 1.0, grav: float = 0.0, additive: bool = false) -> void:
	if _pos.size() >= MAX_PARTS:
		return
	_pos.append(p); _vel.append(v); _life.append(life); _max.append(life); _col.append(c)
	_size.append(size); _grav.append(grav); _add.append(1 if additive else 0)

func _rv(speed: float) -> Vector2:
	return Vector2.from_angle(Game.rng.randf() * TAU) * Game.rng.randf_range(speed * 0.3, speed)

# ---------------------------------------------------------------- API de efectos

func sparks(p: Vector2, n: int, c: Color) -> void:
	for i in n:
		part(p, _rv(150.0), Game.rng.randf_range(0.1, 0.3), c.lightened(0.3), 1.0, 300.0, true)

func spark_at(p: Vector2, v: Vector2, c: Color, life: float) -> void:
	part(p, v, life, c, 1.0, 0.0, true)

func burst(p: Vector2, n: int, c: Color, speed: float) -> void:
	for i in n:
		part(p, _rv(speed), Game.rng.randf_range(0.2, 0.6), c, 1.0 + float(Game.rng.randf() < 0.3), 120.0, true)

func muzzle(p: Vector2, dir: Vector2, c: Color, big: bool) -> void:
	var n := 7 if big else 3
	for i in n:
		var v := dir.rotated(Game.rng.randf_range(-0.5, 0.5)) * Game.rng.randf_range(40.0, 160.0)
		part(p, v, Game.rng.randf_range(0.04, 0.1), c.lightened(0.5), 2.0 if big else 1.0, 0.0, true)
	_booms.append(_boom(p, 9.0 if big else 6.0, 0.05))
	for i in 2 if big else 1:
		part(p, dir * 20.0 + Vector2(0, -15), 0.4, Color(0.5, 0.5, 0.5, 0.35), 2.0, -20.0)

func shell(p: Vector2, dir: Vector2) -> void:
	part(p - dir * 4.0, Vector2(-dir.x * 50.0 + Game.rng.randf_range(-20, 20), -90.0), 0.7, Color(0.95, 0.75, 0.3), 1.0, 600.0)

func flame(p: Vector2) -> void:
	var c := Color(1.0, Game.rng.randf_range(0.35, 0.75), 0.1)
	part(p, Vector2(Game.rng.randf_range(-12, 12), Game.rng.randf_range(-50, -20)), Game.rng.randf_range(0.2, 0.45), c, 1.0 + float(Game.rng.randf() < 0.4), -40.0, true)
	if Game.rng.randf() < 0.2:
		part(p + Vector2(0, -4), Vector2(Game.rng.randf_range(-6, 6), -25), 0.7, Color(0.2, 0.18, 0.18, 0.5), 2.0, -10.0)

func steam(p: Vector2) -> void:
	for i in 10:
		part(p + Vector2(Game.rng.randf_range(-5, 5), 0), Vector2(Game.rng.randf_range(-20, 20), Game.rng.randf_range(-50, -20)), Game.rng.randf_range(0.4, 0.8), Color(0.85, 0.9, 1.0, 0.55), 2.0, -30.0)

func splash(p: Vector2, c: Color, n: int) -> void:
	for i in n:
		part(p, Vector2(Game.rng.randf_range(-50, 50), Game.rng.randf_range(-80, -10)), 0.3, c, 1.0, 500.0)

func drip(p: Vector2, c: Color) -> void:
	part(p, Vector2(0, 10), 0.4, c, 1.0, 400.0)

func dust(p: Vector2, n: int) -> void:
	for i in n:
		part(p + Vector2(Game.rng.randf_range(-3, 3), 0), Vector2(Game.rng.randf_range(-40, 40), Game.rng.randf_range(-20, -5)), 0.35, Color(0.6, 0.58, 0.55, 0.6), 1.0, 30.0)

func explosion(p: Vector2, radius: float) -> void:
	_booms.append(_boom(p, radius, 0.35))
	for i in int(radius * 0.9):
		var c := Color(1.0, Game.rng.randf_range(0.3, 0.9), 0.1)
		part(p, _rv(radius * 5.0), Game.rng.randf_range(0.2, 0.6), c, 1.0 + float(Game.rng.randf() < 0.5), 150.0, true)
	for i in int(radius * 0.4):
		part(p + _rv(radius * 0.3), _rv(40.0) + Vector2(0, -30), Game.rng.randf_range(0.6, 1.2), Color(0.15, 0.13, 0.13, 0.7), 3.0, -20.0)

func disintegrate(p: Vector2, s: Vector2, c: Color) -> void:
	for i in int(s.x * s.y * 0.3):
		var q := p + Vector2(Game.rng.randf_range(-s.x, s.x), Game.rng.randf_range(-s.y, s.y)) * 0.5
		part(q, Vector2(Game.rng.randf_range(-20, 20), Game.rng.randf_range(-60, -10)), Game.rng.randf_range(0.3, 0.8), c.lerp(Color(0.5, 0.2, 0.8), 0.5), 1.0, -40.0, Game.rng.randf() < 0.3)

func slash(origin: Vector2, dir: Vector2, reach: float, c: Color) -> void:
	var s := Slash.new()
	s.origin = origin; s.dir = dir; s.reach = reach; s.life = 0.12; s.color = c
	_slashes.append(s)

func lightning(a: Vector2, b: Vector2, c: Color) -> void:
	var arc := Arc.new()
	arc.a = a; arc.b = b; arc.life = 0.14; arc.color = c
	_arcs.append(arc)
	for i in 3:
		part(b, _rv(120.0), 0.15, c.lightened(0.5), 1.0, 0.0, true)

func float_text(text: String, p: Vector2, c: Color) -> void:
	var t := FText.new()
	t.text = text; t.pos = p; t.life = 1.0; t.color = c
	_texts.append(t)

func add_fire_zone(p: Vector2, width: float, time: float) -> void:
	var z := Zone.new()
	z.pos = p; z.half = width * 0.5; z.life = time; z.oil = false
	zones.append(z)

func add_oil_puddle(p: Vector2, width: float) -> void:
	var z := Zone.new()
	z.pos = p; z.half = width * 0.5; z.life = 25.0; z.oil = true
	zones.append(z)

func _boom(p: Vector2, r: float, life: float) -> Boom:
	var b := Boom.new()
	b.pos = p; b.radius = r; b.life = life
	return b

# ---------------------------------------------------------------- simulación

func _physics_process(delta: float) -> void:
	var n := _pos.size()
	var j := 0
	for i in n:
		var life := _life[i] - delta
		if life <= 0.0:
			continue
		var v := _vel[i]
		v.y += _grav[i] * delta
		v *= 0.97
		_pos[j] = _pos[i] + v * delta
		_vel[j] = v; _life[j] = life; _max[j] = _max[i]; _col[j] = _col[i]
		_size[j] = _size[i]; _grav[j] = _grav[i]; _add[j] = _add[i]
		j += 1
	if j != n:
		_pos.resize(j); _vel.resize(j); _life.resize(j); _max.resize(j); _col.resize(j)
		_size.resize(j); _grav.resize(j); _add.resize(j)
	_tick_zones(delta)
	_age(_arcs, delta)
	_age(_slashes, delta)
	_age(_booms, delta)
	for t in _texts:
		t.pos.y -= 18.0 * delta
	_age(_texts, delta)
	queue_redraw()
	_glow.queue_redraw()

func _age(list: Array, delta: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		list[i].life -= delta
		if list[i].life <= 0.0:
			list.remove_at(i)
		i -= 1

func _tick_zones(delta: float) -> void:
	var i := zones.size() - 1
	while i >= 0:
		var z := zones[i]
		z.life -= delta
		z.tick -= delta
		if z.life <= 0.0:
			zones.remove_at(i)
			i -= 1
			continue
		var band := Rect2(z.pos.x - z.half, z.pos.y - 16.0, z.half * 2.0, 18.0)
		if z.oil:
			# ¿fuego tocando el aceite? → explosión en cadena
			var ignite := false
			for f in zones:
				if not f.oil and absf(f.pos.x - z.pos.x) < f.half + z.half and absf(f.pos.y - z.pos.y) < 12.0:
					ignite = true
					break
			if not ignite:
				for e in Game.enemies:
					if e.targetable() and e.hit_rect().intersects(band):
						if e.burning > 0.0:
							ignite = true
							break
						e.oiled = Elements.OIL_TIME
			if ignite:
				zones.remove_at(i)
				Elements._react("¡NAPALM!", z.pos, Color(1, 0.5, 0.1))
				Elements.explode(z.pos + Vector2(0, -6), z.half + 24.0, 34.0, DamageInfo.FIRE)
				add_fire_zone(z.pos, z.half * 2.6, 6.0)
				i -= 1
				continue
		else:
			if Game.rng.randf() < delta * z.half * 1.2:
				flame(z.pos + Vector2(Game.rng.randf_range(-z.half, z.half), -1))
			if z.tick <= 0.0:
				z.tick = 0.25
				for e: Enemy in Game.enemies.duplicate():
					if e.targetable() and e.hit_rect().intersects(band):
						Elements.apply_hit(e, DamageInfo.make(4.0, DamageInfo.FIRE, Vector2.UP, 0.0))
		i -= 1

# ---------------------------------------------------------------- dibujo

func _draw() -> void:
	for z in zones:
		if z.oil:
			var w := z.half * minf(1.0, (25.0 - z.life) * 4.0 + 0.3)
			draw_rect(Rect2(z.pos.x - w, z.pos.y - 1, w * 2.0, 2), Color(0.08, 0.07, 0.04))
			draw_rect(Rect2(z.pos.x - w * 0.7, z.pos.y - 2, w * 1.4, 1), Color(0.12, 0.1, 0.06))
			draw_rect(Rect2(z.pos.x - w * 0.3, z.pos.y - 2, 3, 1), Color(0.5, 0.45, 0.3))
		else:
			draw_rect(Rect2(z.pos.x - z.half, z.pos.y - 1, z.half * 2.0, 1), Color(1, 0.4, 0.05))
	for i in _pos.size():
		if _add[i]:
			continue
		var c := _col[i]
		c.a *= clampf(_life[i] / _max[i] * 1.5, 0.0, 1.0)
		var s := _size[i]
		draw_rect(Rect2(_pos[i].floor(), Vector2(s, s)), c)
	for s in _slashes:
		var k := s.life / 0.12
		var a0 := s.dir.angle() - 1.1
		draw_arc(s.origin, s.reach * (1.1 - k * 0.2), a0, a0 + 2.2, 10, Color(s.color, k), 2.0)
		draw_arc(s.origin, s.reach * (0.8 - k * 0.2), a0 + 0.3, a0 + 1.9, 8, Color(1, 1, 1, k * 0.8), 1.0)
	for b in _booms:
		var k := 1.0 - b.life / 0.35
		if b.radius > 12.0:
			draw_arc(b.pos, b.radius * (0.4 + k * 0.8), 0.0, TAU, 24, Color(1, 0.9, 0.6, 1.0 - k), 2.0)
	for t in _texts:
		var a := clampf(t.life * 2.0, 0.0, 1.0)
		var p := t.pos.round() - Vector2(_font.get_string_size(t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x * 0.5, 0)
		draw_string_outline(_font, p, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0, 0, 0, a))
		draw_string(_font, p, t.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(t.color, a))

func _draw_glow(ci: Node2D) -> void:
	for i in _pos.size():
		if not _add[i]:
			continue
		var k := _life[i] / _max[i]
		var c := _col[i]
		var s := _size[i]
		ci.draw_rect(Rect2(_pos[i].floor(), Vector2(s, s)), Color(c, k))
		if s > 1.0 or i % 3 == 0:
			Pixel.glow(ci, _pos[i], 3.0 + s * 2.0, Color(c, 0.25 * k))
	for z in zones:
		if not z.oil:
			Pixel.glow(ci, z.pos + Vector2(0, -6), z.half + 10.0, Color(1, 0.45, 0.1, 0.35 * minf(1.0, z.life)))
	for arc in _arcs:
		var pts := _jagged(arc.a, arc.b)
		var k := arc.life / 0.14
		ci.draw_polyline(pts, Color(arc.color, 0.5 * k), 3.0)
		ci.draw_polyline(pts, Color(1, 1, 1, k), 1.0)
		Pixel.glow(ci, arc.b, 14.0, Color(arc.color, 0.5 * k))
	for b in _booms:
		var k := b.life / 0.35 if b.radius > 12.0 else b.life / 0.05
		Pixel.glow(ci, b.pos, b.radius * (1.6 - k * 0.4), Color(1, 0.6, 0.25, 0.8 * k))

func _jagged(a: Vector2, b: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var segs := maxi(3, int(a.distance_to(b) / 8.0))
	var n := (b - a).orthogonal().normalized()
	pts.append(a)
	for i in range(1, segs):
		var t := float(i) / segs
		pts.append((a.lerp(b, t) + n * Game.rng.randf_range(-5.0, 5.0)).round())
	pts.append(b)
	return pts
