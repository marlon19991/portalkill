class_name Overlay
extends Control
## Pausa y Game Over.

enum Mode { NONE, PAUSE, GAMEOVER }

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
	var x := 320.0 - _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string_outline(_font, Vector2(x, y).round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color.BLACK)
	draw_string(_font, Vector2(x, y).round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _draw() -> void:
	if mode == Mode.NONE:
		return
	draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, minf(0.7, _t * 2.0)))
	var gore_names := ["APAGADO", "NORMAL", "EXTREMO"]
	if mode == Mode.PAUSE:
		_txt(110, "PAUSA", 24, Color(1, 0.85, 0.5))
		_txt(150, "A/D moverse · W/Espacio saltar · S+salto bajar plataforma", 8, Color(0.85, 0.85, 0.9))
		_txt(164, "Ratón apuntar · Clic disparar · 1-6 / Q E / rueda cambiar arma", 8, Color(0.85, 0.85, 0.9))
		_txt(190, "[G] Gore: %s" % gore_names[Game.gore], 8, Color(1, 0.4, 0.4))
		_txt(204, "[F3] Rendimiento   ·   [Esc] Continuar", 8, Color(0.7, 0.7, 0.75))
		_txt(240, "Combos: Mojado+Eléctrico · Aceite+Fuego · Corte = desmembrar", 8, Color(0.5, 1, 0.8))
	else:
		_txt(130, "HAS CAÍDO", 24, Color(0.9, 0.15, 0.2))
		_txt(165, "Piso %d   ·   %d bajas" % [Game.floor_index + 1, Game.kills], 8, Color(0.9, 0.9, 0.9))
		if _t > 0.8:
			_txt(200, "[R] Volver a intentarlo", 8, Color(1, 0.85, 0.5, 0.6 + sin(_t * 5.0) * 0.4))
