class_name Pixel
extends RefCounted
## Utilidades de dibujo pixel art y recursos compartidos (texturas de brillo).

static var _glow: Texture2D

## Textura radial suave para brillos aditivos (una sola instancia compartida).
static func glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.35, Color(1, 1, 1, 0.35))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_glow = t
	return _glow

## Hash entero determinista para patrones de tiles sin guardar datos.
static func hash2(x: int, y: int) -> int:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return h

static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_texture_rect(glow_tex(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)
