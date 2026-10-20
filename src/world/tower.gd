class_name Tower
extends Node2D
## La torre: pisos apilados con ruta en zigzag. Colisión analítica (sin grid ni física):
## el suelo de cada piso es un rectángulo, así que las consultas son baratas.

const W := 360.0
const TOP := 44.0          ## bajo la barra superior del HUD
const FLOOR_H := 124.0
const FLOORS := 4
const SLAB := 12.0         ## grosor de cada losa
const WALL := 8.0
const PATH_MARGIN := 26.0  ## dónde están los portales respecto a la pared
const SLOT_X := [72.0, 126.0, 180.0, 234.0, 288.0]
const BOTTOM := TOP + FLOOR_H * FLOORS

const THEMES := [
	{bg = Color("12161a"), bg2 = Color("1a2126"), slab = Color("3b4a4a"), edge = Color("6b8f7a"), accent = Color("7cff9a")},
	{bg = Color("1a0f0c"), bg2 = Color("261410"), slab = Color("4a2f26"), edge = Color("c46a2f"), accent = Color("ff8a2a")},
	{bg = Color("0b1220"), bg2 = Color("111a2c"), slab = Color("2c3a52"), edge = Color("5fb4d9"), accent = Color("5ff0ff")},
	{bg = Color("120b18"), bg2 = Color("1c1024"), slab = Color("3a2a46"), edge = Color("9a6ad0"), accent = Color("ff4a8a")},
]

var _glow: GlowLayer

func _ready() -> void:
	_glow = GlowLayer.new(_draw_glow)
	_glow.z_index = 1
	add_child(_glow)

# ---------------------------------------------------------------- geometría de la ruta

static func ceiling_y(f: int) -> float:
	return TOP + f * FLOOR_H

## Superficie por donde caminan los enemigos del piso f.
static func ground_y(f: int) -> float:
	return TOP + (f + 1) * FLOOR_H - SLAB

## Dirección de marcha: el piso 0 va a la izquierda (start a la derecha), luego alterna.
static func dir(f: int) -> float:
	return -1.0 if f % 2 == 0 else 1.0

static func start_x(f: int) -> float:
	return W - PATH_MARGIN if dir(f) < 0.0 else PATH_MARGIN

static func end_x(f: int) -> float:
	return PATH_MARGIN if dir(f) < 0.0 else W - PATH_MARGIN

static func floor_at(y: float) -> int:
	return clampi(int((y - TOP) / FLOOR_H), 0, FLOORS - 1)

## Rectángulo tocable de una casilla (ancho generoso para el dedo).
static func slot_rect(f: int, i: int) -> Rect2:
	return Rect2(SLOT_X[i] - 26.0, ceiling_y(f), 52.0, FLOOR_H - SLAB)

# ---------------------------------------------------------------- colisión analítica

func is_wall(p: Vector2) -> bool:
	if p.x < WALL or p.x > W - WALL or p.y < TOP - SLAB or p.y > BOTTOM:
		return true
	var local := fposmod(p.y - TOP, FLOOR_H)
	return local >= FLOOR_H - SLAB

func is_solid(p: Vector2) -> bool:
	return is_wall(p)

func ground_below(p: Vector2, _max_dist: float = 200.0) -> Vector2:
	return Vector2(p.x, ground_y(floor_at(p.y)))

# ---------------------------------------------------------------- dibujo (cacheado)

func _draw() -> void:
	draw_rect(Rect2(0, TOP - SLAB - 4, W, BOTTOM - TOP + SLAB + 8), Color(0.02, 0.015, 0.03))
	for f in FLOORS:
		_draw_floor(f)
	# techo de la torre
	_draw_slab(Rect2(0, TOP - SLAB, W, SLAB), THEMES[0])

func _draw_floor(f: int) -> void:
	var t: Dictionary = THEMES[f % THEMES.size()]
	var top := ceiling_y(f)
	var bg: Color = t.bg
	var bg2: Color = t.bg2
	var h := FLOOR_H - SLAB
	draw_rect(Rect2(0, top, W, h), bg)
	# pilares y ventanas de fondo
	for i in 4:
		var px := 30.0 + i * 96.0
		draw_rect(Rect2(px, top, 16, h), bg2)
		draw_rect(Rect2(px + 1, top, 1, h), bg2.lightened(0.06))
		draw_rect(Rect2(px + 15, top, 1, h), bg.darkened(0.35))
	for i in 3:
		var wx := 72.0 + i * 96.0
		var wy := top + 24.0
		draw_rect(Rect2(wx, wy, 14, 22), bg.darkened(0.45))
		draw_rect(Rect2(wx + 6, wy, 2, 22), bg2)
		draw_rect(Rect2(wx, wy + 10, 14, 2), bg2)
	draw_rect(Rect2(0, top + 6, W, 2), bg2.lightened(0.03))
	for i in 50:
		var hh := Pixel.hash2(i, f * 31 + 7)
		draw_rect(Rect2(hh % int(W), top + (hh >> 9) % int(h), 1, 1), bg2.lightened(0.1))
	# flechas tenues de la ruta (lectura rápida del sentido de marcha)
	var d := dir(f)
	for i in 6:
		var ax := 54.0 + i * 50.0
		var ay := ground_y(f) - 30.0
		var c := Color(t.accent, 0.08)
		draw_rect(Rect2(ax, ay, 8, 1), c)
		draw_rect(Rect2(ax + (8 if d > 0 else -1), ay - 1, 1, 3), c)
	# paredes laterales
	_draw_wall(Rect2(0, top, WALL, h), t)
	_draw_wall(Rect2(W - WALL, top, WALL, h), t)
	# losa (suelo de este piso)
	_draw_slab(Rect2(0, ground_y(f), W, SLAB), t)

func _draw_wall(r: Rect2, t: Dictionary) -> void:
	var c: Color = t.slab
	draw_rect(r, c.darkened(0.15))
	var y := r.position.y
	while y < r.end.y:
		draw_rect(Rect2(r.position.x, y, r.size.x, 1), c.darkened(0.45))
		y += 8.0

func _draw_slab(r: Rect2, t: Dictionary) -> void:
	var c: Color = t.slab
	var e: Color = t.edge
	draw_rect(r, c)
	var x := 0.0
	var row := 0
	while x < W:
		var hh := Pixel.hash2(int(x), int(r.position.y))
		draw_rect(Rect2(x, r.position.y, 16, r.size.y), c.darkened(0.06 * (hh % 3)))
		draw_rect(Rect2(x + 15, r.position.y + 3, 1, r.size.y - 3), c.darkened(0.4))
		if hh % 5 == 0:
			draw_rect(Rect2(x + 3 + hh % 8, r.position.y + 5, 2, 1), c.lightened(0.12))
		x += 16.0
		row += 1
	draw_rect(Rect2(r.position, Vector2(W, 2)), e)
	draw_rect(Rect2(r.position + Vector2(0, 2), Vector2(W, 1)), e.darkened(0.45))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(W, 2)), c.darkened(0.55))

func _draw_glow(ci: Node2D) -> void:
	for f in FLOORS:
		var t: Dictionary = THEMES[f % THEMES.size()]
		for i in 3:
			Pixel.glow(ci, Vector2(79.0 + i * 96.0, ceiling_y(f) + 35.0), 22.0, Color(t.accent, 0.06))
