class_name Level
extends Node2D
## Piso: grid lógico (O(1) para partículas y balas), colisión fusionada y dibujo cacheado.

const TILE := 16
const W := 40
const H := 23
const EMPTY := 0
const SOLID := 1
const ONEWAY := 2
const PLAT_THICK := 5

var grid := PackedByteArray()
var theme: Dictionary
var entry_pos := Vector2.ZERO
var exit_pos := Vector2.ZERO
var spawn_pos := Vector2.ZERO
var _body: StaticBody2D
var _oneway: StaticBody2D
var _bg: Node2D
var _bg_glow: GlowLayer

func _ready() -> void:
	_bg = Node2D.new()
	_bg.z_index = -20
	_bg.draw.connect(_draw_bg.bind(_bg))
	add_child(_bg)
	_bg_glow = GlowLayer.new(_draw_bg_glow)
	_bg_glow.z_index = -19
	add_child(_bg_glow)

func build(layout: Array, theme_: Dictionary) -> void:
	theme = theme_
	grid.resize(W * H)
	grid.fill(EMPTY)
	for y in H:
		for x in W:
			var c := "."
			if x == 0 or x == W - 1 or y == 0 or y == H - 1:
				c = "#"
			elif y - 1 < layout.size():
				var row: String = layout[y - 1]
				if x - 1 < row.length():
					c = row[x - 1]
			var center := Vector2(x * TILE + TILE * 0.5, y * TILE + TILE * 0.5)
			match c:
				"#": grid[y * W + x] = SOLID
				"=": grid[y * W + x] = ONEWAY
				"E": entry_pos = center
				"X": exit_pos = center
				"P": spawn_pos = center
	_build_collision()
	queue_redraw()
	_bg.queue_redraw()
	_bg_glow.queue_redraw()

func cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return SOLID
	return grid[y * W + x]

## Sólido para partículas/balas: tiles sólidos y la franja superior de plataformas.
func is_solid(p: Vector2) -> bool:
	var x := int(floorf(p.x / TILE))
	var y := int(floorf(p.y / TILE))
	var c := cell(x, y)
	if c == SOLID:
		return true
	if c == ONEWAY:
		return p.y - y * TILE < PLAT_THICK
	return false

func is_wall(p: Vector2) -> bool:
	return cell(int(floorf(p.x / TILE)), int(floorf(p.y / TILE))) == SOLID

## Primer punto de suelo bajo p (para charcos y fuego en el suelo).
func ground_below(p: Vector2, max_dist: float = 200.0) -> Vector2:
	var q := p
	var steps := int(max_dist / 2.0)
	for i in steps:
		if is_solid(q):
			return Vector2(q.x, floorf(q.y / 2.0) * 2.0)
		q.y += 2.0
	return p

## Fusiona tiles en rectángulos grandes: pocos shapes, física barata.
func _build_collision() -> void:
	for b in [_body, _oneway]:
		if b:
			b.queue_free()
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_oneway = StaticBody2D.new()
	_oneway.collision_layer = 2
	_oneway.collision_mask = 0
	add_child(_body)
	add_child(_oneway)
	var used := PackedByteArray()
	used.resize(W * H)
	for y in H:
		for x in W:
			var c := grid[y * W + x]
			if c == EMPTY or used[y * W + x]:
				continue
			var w := 1
			while x + w < W and grid[y * W + x + w] == c and not used[y * W + x + w]:
				w += 1
			var h := 1
			if c == SOLID:
				var ok := true
				while ok and y + h < H:
					for i in w:
						if grid[(y + h) * W + x + i] != c or used[(y + h) * W + x + i]:
							ok = false
							break
					if ok:
						h += 1
			for yy in h:
				for xx in w:
					used[(y + yy) * W + x + xx] = 1
			var shape := RectangleShape2D.new()
			var cs := CollisionShape2D.new()
			if c == SOLID:
				shape.size = Vector2(w * TILE, h * TILE)
				cs.position = Vector2(x * TILE, y * TILE) + shape.size * 0.5
				cs.shape = shape
				_body.add_child(cs)
			else:
				shape.size = Vector2(w * TILE, PLAT_THICK)
				cs.position = Vector2(x * TILE + w * TILE * 0.5, y * TILE + PLAT_THICK * 0.5)
				cs.shape = shape
				cs.one_way_collision = true
				_oneway.add_child(cs)

# ---------------------------------------------------------------- dibujo
# Los CanvasItem guardan los comandos de _draw: esto se dibuja una vez por piso.

func _draw() -> void:
	var solid: Color = theme.solid
	var edge: Color = theme.edge
	var plat: Color = theme.plat
	for y in H:
		for x in W:
			var c := grid[y * W + x]
			var o := Vector2(x * TILE, y * TILE)
			if c == SOLID:
				_draw_solid(o, x, y, solid, edge)
			elif c == ONEWAY:
				_draw_plat(o, x, y, plat, edge)

func _draw_solid(o: Vector2, x: int, y: int, solid: Color, edge: Color) -> void:
	var h := Pixel.hash2(x, y)
	draw_rect(Rect2(o, Vector2(TILE, TILE)), solid.darkened(0.08 * (h % 3)))
	# ladrillos
	var off := 8 if y % 2 == 0 else 0
	var mortar := solid.darkened(0.35)
	draw_rect(Rect2(o + Vector2(0, 7), Vector2(TILE, 1)), mortar)
	draw_rect(Rect2(o + Vector2(0, 15), Vector2(TILE, 1)), mortar)
	draw_rect(Rect2(o + Vector2((off + 4) % 16, 0), Vector2(1, 7)), mortar)
	draw_rect(Rect2(o + Vector2((off + 12) % 16, 8), Vector2(1, 7)), mortar)
	if h % 7 == 0:
		draw_rect(Rect2(o + Vector2(3 + h % 9, 3 + (h >> 4) % 9), Vector2(2, 1)), solid.lightened(0.12))
	# borde superior expuesto: musgo/óxido y luz
	if cell(x, y - 1) != SOLID:
		draw_rect(Rect2(o, Vector2(TILE, 2)), edge)
		draw_rect(Rect2(o + Vector2(0, 2), Vector2(TILE, 1)), edge.darkened(0.4))
		if h % 3 == 0:
			draw_rect(Rect2(o + Vector2(h % 13, 3), Vector2(1, 2 + h % 3)), edge.darkened(0.3))
	if cell(x, y + 1) != SOLID:
		draw_rect(Rect2(o + Vector2(0, TILE - 2), Vector2(TILE, 2)), solid.darkened(0.5))
	if cell(x - 1, y) != SOLID:
		draw_rect(Rect2(o, Vector2(1, TILE)), solid.lightened(0.1))
	if cell(x + 1, y) != SOLID:
		draw_rect(Rect2(o + Vector2(TILE - 1, 0), Vector2(1, TILE)), solid.darkened(0.45))

func _draw_plat(o: Vector2, x: int, y: int, plat: Color, edge: Color) -> void:
	draw_rect(Rect2(o, Vector2(TILE, PLAT_THICK)), plat)
	draw_rect(Rect2(o, Vector2(TILE, 1)), plat.lightened(0.3))
	draw_rect(Rect2(o + Vector2(0, PLAT_THICK - 1), Vector2(TILE, 1)), plat.darkened(0.5))
	draw_rect(Rect2(o + Vector2(7, 1), Vector2(1, PLAT_THICK - 2)), plat.darkened(0.3))
	# soportes colgantes en los extremos
	if cell(x - 1, y) != ONEWAY or cell(x + 1, y) != ONEWAY:
		var sx := 2 if cell(x - 1, y) != ONEWAY else TILE - 4
		draw_rect(Rect2(o + Vector2(sx, PLAT_THICK), Vector2(2, 4)), plat.darkened(0.4))
	if Pixel.hash2(x, y) % 4 == 0:
		draw_rect(Rect2(o + Vector2(Pixel.hash2(y, x) % 14, PLAT_THICK), Vector2(1, 3)), edge.darkened(0.5))

func _draw_bg(ci: Node2D) -> void:
	if theme.is_empty():
		return
	var bg: Color = theme.bg
	var bg2: Color = theme.bg2
	ci.draw_rect(Rect2(0, 0, W * TILE, H * TILE), bg)
	# pilares y arcos de fondo
	for i in 6:
		var px := 40 + i * 112
		ci.draw_rect(Rect2(px, 0, 22, H * TILE), bg2)
		ci.draw_rect(Rect2(px + 2, 0, 2, H * TILE), bg2.lightened(0.05))
		ci.draw_rect(Rect2(px + 20, 0, 2, H * TILE), bg.darkened(0.3))
	# ventanas lejanas
	for i in 5:
		var wx := 90 + i * 112
		for j in 2:
			var wy := 50 + j * 150
			ci.draw_rect(Rect2(wx, wy, 14, 22), bg.darkened(0.4))
			ci.draw_rect(Rect2(wx + 6, wy, 2, 22), bg2)
			ci.draw_rect(Rect2(wx, wy + 10, 14, 2), bg2)
	# tuberías y cables
	for i in 3:
		var py := 30 + i * 120
		ci.draw_rect(Rect2(0, py, W * TILE, 3), bg2.lightened(0.04))
		ci.draw_rect(Rect2(0, py + 3, W * TILE, 1), bg.darkened(0.4))
	# polvo/manchas fijas
	for i in 160:
		var h := Pixel.hash2(i, 77)
		ci.draw_rect(Rect2(h % (W * TILE), (h >> 10) % (H * TILE), 1, 1), bg2.lightened(0.08))

func _draw_bg_glow(ci: Node2D) -> void:
	if theme.is_empty():
		return
	var a: Color = theme.accent
	for i in 5:
		for j in 2:
			Pixel.glow(ci, Vector2(97 + i * 112, 61 + j * 150), 26.0, Color(a, 0.07))
	# viñeta inversa: luz cenital tenue
	Pixel.glow(ci, Vector2(320, 0), 280.0, Color(a, 0.05))
