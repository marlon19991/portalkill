class_name Portal
extends Node2D
## Portal animado. Entrada: escupe enemigos. Salida: se abre al limpiar el piso.

signal entered

var is_exit := false
var open := false
var color := Color(1, 0.2, 0.35)
var _t := 0.0
var _pulse := 0.0
var _glow: GlowLayer

func setup(exit_: bool, accent: Color) -> void:
	is_exit = exit_
	open = not exit_
	color = accent if exit_ else Color(1.0, 0.18, 0.3)

func _ready() -> void:
	_glow = GlowLayer.new(_draw_glow)
	add_child(_glow)

func pulse() -> void:
	_pulse = 1.0

func set_open(v: bool) -> void:
	open = v
	if v:
		_pulse = 1.5
		Game.fx.burst(global_position, 30, color, 140.0)
		Events.screen_shake.emit(0.3)

func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 2.5)
	queue_redraw()
	_glow.queue_redraw()
	if open and Game.fx and Game.rng.randf() < delta * 14.0:
		var a := Game.rng.randf() * TAU
		Game.fx.spark_at(global_position + Vector2(cos(a) * 9.0, sin(a) * 15.0), Vector2(cos(a), sin(a)) * -12.0, color, 0.6)
	if is_exit and open and Game.player and not Game.player.dead:
		if Game.player.center().distance_to(global_position) < 13.0:
			open = false
			entered.emit()

func _draw() -> void:
	var c := color if open else Color(0.35, 0.35, 0.4)
	var r := Vector2(10, 16) * (1.0 + _pulse * 0.15)
	# marco de piedra
	draw_rect(Rect2(-13, -19, 3, 36), Color(0.2, 0.18, 0.22))
	draw_rect(Rect2(10, -19, 3, 36), Color(0.2, 0.18, 0.22))
	draw_rect(Rect2(-13, -21, 26, 3), Color(0.25, 0.22, 0.27))
	draw_rect(Rect2(-12, -20, 24, 1), Color(0.4, 0.36, 0.42))
	if not open:
		_ellipse(Vector2.ZERO, r, Color(0.05, 0.05, 0.07))
		_ellipse(Vector2.ZERO, r * 0.6, Color(0.12, 0.12, 0.15))
		return
	# remolino: anillos concéntricos que giran
	_ellipse(Vector2.ZERO, r, c.darkened(0.6))
	for i in 4:
		var k := 1.0 - i * 0.22
		var off := Vector2(sin(_t * 3.0 + i), cos(_t * 2.3 + i * 1.7)) * (1.5 * i)
		_ellipse(off, r * k, c.lerp(Color.BLACK, 0.15 * i).lightened(0.12 * i))
	_ellipse(Vector2.ZERO, r * 0.25, Color(0.02, 0.0, 0.03))
	for i in 10:
		var a := _t * (2.0 + i * 0.3) + i * 0.6
		var p := Vector2(cos(a) * r.x * 0.8, sin(a) * r.y * 0.8)
		draw_rect(Rect2(p.round(), Vector2(1, 1)), c.lightened(0.5))

func _draw_glow(ci: Node2D) -> void:
	if not open:
		return
	var s := 1.0 + _pulse * 0.6 + sin(_t * 4.0) * 0.06
	Pixel.glow(ci, Vector2.ZERO, 44.0 * s, Color(color, 0.45))
	Pixel.glow(ci, Vector2.ZERO, 16.0 * s, Color(color.lightened(0.4), 0.5))

func _ellipse(o: Vector2, r: Vector2, c: Color) -> void:
	# elipse "pixelada" por filas → bordes limpios
	var rows := int(r.y)
	for y in range(-rows, rows + 1):
		var w := r.x * sqrt(maxf(0.0, 1.0 - float(y * y) / (r.y * r.y)))
		var wi := roundf(w)
		if wi > 0:
			draw_rect(Rect2(roundf(o.x - wi), roundf(o.y) + y, wi * 2.0, 1), c)
