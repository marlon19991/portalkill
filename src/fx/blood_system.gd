class_name BloodSystem
extends Node2D
## Sangre en dos fases:
## 1) Gotas vivas simuladas en PackedArrays (sin nodos) con colisión contra el grid.
## 2) Al tocar una superficie, la gota se "pinta" en un lienzo persistente
##    (SubViewport que nunca se limpia) y sale de la simulación.
## Resultado: manchas ilimitadas con costo constante por frame.

const GRAVITY := 620.0
const MAX_DROPS := 3000

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _life := PackedFloat32Array()
var _col := PackedColorArray()
var _size := PackedFloat32Array()

var _canvas: SubViewport
var _painter: Node2D
var _stain: Sprite2D
var _pending_rects: Array[Rect2] = []
var _pending_cols := PackedColorArray()
var _pending_gibs: Array = [] # [pos, rot, size, color]
var _painted := false

func _ready() -> void:
	_canvas = SubViewport.new()
	_canvas.size = Vector2i(int(Tower.W), int(Tower.BOTTOM + 8.0))
	_canvas.transparent_bg = true
	_canvas.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_canvas)
	_painter = Node2D.new()
	_painter.draw.connect(_paint)
	_canvas.add_child(_painter)
	_stain = Sprite2D.new()
	_stain.texture = _canvas.get_texture()
	_stain.centered = false
	_stain.z_as_relative = false
	_stain.z_index = 1
	add_child(_stain)

func clear() -> void:
	_pos.clear(); _vel.clear(); _life.clear(); _col.clear(); _size.clear()
	_pending_rects.clear(); _pending_cols.clear(); _pending_gibs.clear()
	_canvas.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame
	_canvas.render_target_clear_mode = SubViewport.CLEAR_MODE_NEVER

func count() -> int:
	return _pos.size()

func _add(p: Vector2, v: Vector2, c: Color, s: float, life: float = 3.0) -> void:
	if _pos.size() >= MAX_DROPS:
		return
	_pos.append(p); _vel.append(v); _col.append(c); _size.append(s); _life.append(life)

func spray(p: Vector2, dir: Vector2, n: int, c: Color) -> void:
	if Game.gore == Game.Gore.OFF:
		return
	n = int(n * Game.gore_mult())
	for i in n:
		var a := dir.angle() + Game.rng.randf_range(-0.55, 0.55)
		_add(p, Vector2.from_angle(a) * Game.rng.randf_range(50.0, 170.0), _vary(c), 1.0 if Game.rng.randf() < 0.7 else 2.0)

func burst(p: Vector2, dir: Vector2, n: int, c: Color) -> void:
	if Game.gore == Game.Gore.OFF:
		return
	for i in n:
		var v := Vector2.from_angle(Game.rng.randf() * TAU) * Game.rng.randf_range(30.0, 230.0)
		v += dir * 90.0 + Vector2(0, -80)
		_add(p + Vector2(Game.rng.randf_range(-3, 3), Game.rng.randf_range(-3, 3)), v, _vary(c), 1.0 if Game.rng.randf() < 0.6 else 2.0)

func drip(p: Vector2, c: Color) -> void:
	_add(p, Vector2(Game.rng.randf_range(-10, 10), Game.rng.randf_range(0, 20)), _vary(c), 1.0)

func _vary(c: Color) -> Color:
	return c.darkened(Game.rng.randf() * 0.3).lightened(Game.rng.randf() * 0.08)

## Deja un pedazo (gib) pintado para siempre en el escenario.
func stamp_gib(p: Vector2, rot: float, s: Vector2, c: Color) -> void:
	_pending_gibs.append([p, rot, s, c])

func stamp(r: Rect2, c: Color) -> void:
	_pending_rects.append(r)
	_pending_cols.append(c)

func _physics_process(delta: float) -> void:
	var level := Game.level
	var bounds := Rect2(-8, Tower.TOP - 20.0, Tower.W + 16, Tower.BOTTOM - Tower.TOP + 40.0)
	# compactación in-place: una sola pasada, un solo resize al final
	var n := _pos.size()
	var j := 0
	for i in n:
		var p := _pos[i]
		var v := _vel[i]
		v.y += GRAVITY * delta
		v *= 0.995
		var np := p + v * delta
		var life := _life[i] - delta
		if life <= 0.0 or not bounds.has_point(np):
			continue
		if level.is_solid(np):
			_splat(p, np, v, _col[i], _size[i])
			continue
		_pos[j] = np; _vel[j] = v; _life[j] = life; _col[j] = _col[i]; _size[j] = _size[i]
		j += 1
	if j != n:
		_pos.resize(j); _vel.resize(j); _life.resize(j); _col.resize(j); _size.resize(j)
	queue_redraw()
	if not _pending_rects.is_empty() or not _pending_gibs.is_empty() or _painted:
		_painter.queue_redraw()

func _splat(p: Vector2, np: Vector2, v: Vector2, c: Color, s: float) -> void:
	var level := Game.level
	var hit_wall_side := level.is_wall(Vector2(np.x, p.y)) and not level.is_solid(Vector2(p.x, np.y))
	var at := p.floor()
	if hit_wall_side:
		# chorreo vertical en la pared
		var l := Game.rng.randi_range(2, 6) if Game.gore == Game.Gore.EXTREME else Game.rng.randi_range(1, 4)
		stamp(Rect2(at, Vector2(1, l)), c)
	else:
		var w := Game.rng.randi_range(1, 3) + int(s) - 1 + int(absf(v.x) / 90.0)
		stamp(Rect2(at + Vector2(-floorf(w * 0.5), 0), Vector2(w, 1)), c)
		if s > 1.0 and Game.rng.randf() < 0.4:
			stamp(Rect2(at + Vector2(0, 1), Vector2(1, 1)), c.darkened(0.3))

func _paint() -> void:
	for k in _pending_rects.size():
		_painter.draw_rect(_pending_rects[k], _pending_cols[k])
	for g in _pending_gibs:
		var s: Vector2 = g[2]
		var c: Color = g[3]
		_painter.draw_set_transform(g[0], g[1], Vector2.ONE)
		_painter.draw_rect(Rect2(-s * 0.5, s), c.darkened(0.35))
		_painter.draw_rect(Rect2(-s * 0.5, Vector2(s.x, 1)), c.darkened(0.15))
		_painter.draw_rect(Rect2(Vector2(-s.x * 0.5, s.y * 0.5 - 1), Vector2(s.x, 1)), Color(0.35, 0.02, 0.04))
		_painter.draw_set_transform(Vector2.ZERO)
	_painted = not _pending_rects.is_empty() or not _pending_gibs.is_empty()
	_pending_rects.clear()
	_pending_cols.clear()
	_pending_gibs.clear()

func _draw() -> void:
	for i in _pos.size():
		var s := _size[i]
		draw_rect(Rect2(_pos[i].floor(), Vector2(s, s)), _col[i])
