class_name Overlay
extends Control
## Pausa, derrota y victoria.

enum Mode { NONE, PAUSE, DEFEAT, VICTORY }

var mode := Mode.NONE
var _font: Font
var _t := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font

func show_mode(m: Mode) -> void:
	mode = m
	_t = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	if mode != Mode.NONE:
		queue_redraw()

func _txt(y: float, s: String, size: int, c: Color) -> void:
	var x := get_viewport_rect().size.x * 0.5 - _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string_outline(_font, Vector2(x, y).round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color.BLACK)
	draw_string(_font, Vector2(x, y).round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _draw() -> void:
	if mode == Mode.NONE:
		return
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, minf(0.75, _t * 2.0)))
	var blink := Color(1, 0.85, 0.5, 0.6 + sin(_t * 5.0) * 0.4)
	match mode:
		Mode.PAUSE:
			_txt(220, "PAUSA", 24, Color(1, 0.85, 0.5))
			_txt(262, "Toca una X para construir una trampa.", 8, Color(0.85, 0.85, 0.9))
			_txt(276, "Toca una trampa para mejorarla o venderla.", 8, Color(0.85, 0.85, 0.9))
			_txt(300, "Combos: Aspersor  >  Tesla (cadena x2)", 8, Color(0.5, 1, 0.8))
			_txt(314, "Aceite  >  Lanzallamas (NAPALM)", 8, Color(0.5, 1, 0.8))
			_txt(328, "Sierra = desmembrar · Pisón = empujar atrás", 8, Color(0.5, 1, 0.8))
			_txt(370, "Toca para continuar", 8, blink)
		Mode.DEFEAT:
			_txt(240, "LA TORRE CAYÓ", 24, Color(0.9, 0.15, 0.2))
			_txt(276, "Oleada %d · %d bajas" % [Game.wave, Game.kills], 8, Color(0.9, 0.9, 0.9))
			if _t > 0.8:
				_txt(320, "Toca para reintentar", 8, blink)
		Mode.VICTORY:
			_txt(240, "¡TORRE DEFENDIDA!", 24, Color(0.5, 1, 0.6))
			_txt(276, "%d oleadas · %d bajas · %d vidas" % [Game.TOTAL_WAVES, Game.kills, Game.lives], 8, Color(0.9, 0.9, 0.9))
			if _t > 0.8:
				_txt(320, "Toca para jugar de nuevo", 8, blink)
