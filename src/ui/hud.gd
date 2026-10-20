class_name Hud
extends Control
## HUD táctil dibujado a mano: barra superior (vidas, oro, oleada, botones)
## y panel inferior contextual (iniciar oleada / construir / mejorar-vender).

signal build_requested(id: StringName)
signal upgrade_requested
signal sell_requested
signal cancel_requested
signal start_wave_requested
signal speed_toggled
signal gore_toggled
signal pause_toggled

var director: WaveDirector
var selected_slot := Vector2i(-1, -1)
var selected_trap: Trap
var speed := 1
var debug := false
var banner := ""
var banner_t := 0.0
var banner_color := Color.WHITE
var damage_flash := 0.0
var _font: Font
var _buttons: Array = [] # [Rect2, Callable, enabled]
var _shown_gold := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_shown_gold = Game.gold
	Events.wave_started.connect(func(w: int, t: int) -> void: show_banner("OLEADA %d / %d" % [w, t], Color(1, 0.35, 0.35)))
	Events.wave_cleared.connect(func(_w: int, b: int) -> void: show_banner("OLEADA SUPERADA  +%d" % b, Color(0.5, 1, 0.7)))
	Events.enemy_leaked.connect(func(_e: Node2D, _n: int) -> void: damage_flash = 0.4)

func show_banner(text: String, c: Color) -> void:
	banner = text
	banner_color = c
	banner_t = 2.0

func _process(delta: float) -> void:
	banner_t = maxf(0.0, banner_t - delta)
	damage_flash = maxf(0.0, damage_flash - delta)
	_shown_gold = move_toward(_shown_gold, Game.gold, maxf(1.0, absf(Game.gold - _shown_gold)) * delta * 8.0)
	queue_redraw()

## Devuelve true si el toque cayó en un botón del HUD.
func handle_tap(p: Vector2) -> bool:
	for b in _buttons:
		if (b[0] as Rect2).has_point(p):
			if b[2]:
				(b[1] as Callable).call()
			return true
	return p.y < Tower.TOP - Tower.SLAB or p.y > Tower.BOTTOM + 2.0

func _btn(r: Rect2, label: String, action: Callable, enabled := true, accent := Color(1, 0.85, 0.4), sub := "") -> void:
	_buttons.append([r, action, enabled])
	var base := Color(0.13, 0.1, 0.15) if enabled else Color(0.07, 0.06, 0.08)
	draw_rect(r.grow(1), Color(0, 0, 0, 0.9))
	draw_rect(r, base)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(accent, 0.9 if enabled else 0.3))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.6))
	var c := Color.WHITE if enabled else Color(1, 1, 1, 0.35)
	var ty := r.position.y + (r.size.y * 0.5 + 3.0 if sub == "" else r.size.y * 0.5 - 1.0)
	_text(Vector2(r.get_center().x, ty), label, 8, c, true)
	if sub != "":
		_text(Vector2(r.get_center().x, ty + 10.0), sub, 8, Color(accent, 1.0 if enabled else 0.35), true)

func _text(p: Vector2, s: String, size: int, c: Color, center := false) -> void:
	var pos := p
	if center:
		pos.x -= _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	pos = pos.round()
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, c.a))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _heart(p: Vector2, c: Color) -> void:
	draw_rect(Rect2(p + Vector2(1, 0), Vector2(2, 1)), c)
	draw_rect(Rect2(p + Vector2(4, 0), Vector2(2, 1)), c)
	draw_rect(Rect2(p + Vector2(0, 1), Vector2(7, 2)), c)
	draw_rect(Rect2(p + Vector2(1, 3), Vector2(5, 1)), c)
	draw_rect(Rect2(p + Vector2(2, 4), Vector2(3, 1)), c)
	draw_rect(Rect2(p + Vector2(3, 5), Vector2(1, 1)), c)

func _coin(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(1, 0), Vector2(4, 6)), Color(1, 0.8, 0.2))
	draw_rect(Rect2(p + Vector2(0, 1), Vector2(6, 4)), Color(1, 0.8, 0.2))
	draw_rect(Rect2(p + Vector2(2, 1), Vector2(1, 4)), Color(1, 0.95, 0.6))

func _play_icon(p: Vector2, c: Color) -> void:
	for i in 4:
		draw_rect(Rect2(p + Vector2(i, i), Vector2(1, 8 - i * 2)), c)

func _draw() -> void:
	_buttons.clear()
	var vs := get_viewport_rect().size
	# --- barra superior
	draw_rect(Rect2(0, 0, vs.x, Tower.TOP - Tower.SLAB - 2), Color(0.03, 0.02, 0.04))
	_heart(Vector2(8, 10), Color(0.9, 0.15, 0.2))
	_text(Vector2(18, 16), "%d" % Game.lives, 8, Color.WHITE)
	_coin(Vector2(44, 10))
	_text(Vector2(54, 16), "%d" % roundi(_shown_gold), 8, Color(1, 0.85, 0.35))
	_text(Vector2(96, 16), "OLEADA %d/%d" % [Game.wave, Game.TOTAL_WAVES], 8, Color(1, 0.6, 0.55))
	var gore_label: String = ["SIN GORE", "GORE", "GORE+"][Game.gore]
	_btn(Rect2(206, 4, 54, 20), gore_label, func() -> void: gore_toggled.emit(), true, Color(0.9, 0.2, 0.25))
	_btn(Rect2(264, 4, 40, 20), "x%d" % speed, func() -> void: speed_toggled.emit(), true, Color(0.5, 0.9, 1.0))
	_btn(Rect2(308, 4, 44, 20), "PAUSA", func() -> void: pause_toggled.emit(), true, Color(0.8, 0.8, 0.85))
	# --- panel inferior
	var top := Tower.BOTTOM + 4.0
	var h := vs.y - top
	draw_rect(Rect2(0, top, vs.x, h), Color(0.04, 0.03, 0.05))
	draw_rect(Rect2(0, top, vs.x, 1), Color(0.3, 0.25, 0.3))
	if selected_trap:
		_panel_trap(top)
	elif selected_slot.x >= 0:
		_panel_build(top)
	else:
		_panel_idle(top)
	# --- avisos
	if damage_flash > 0.0:
		var a := damage_flash * 0.6
		draw_rect(Rect2(0, 0, 4, vs.y), Color(0.9, 0, 0, a))
		draw_rect(Rect2(vs.x - 4, 0, 4, vs.y), Color(0.9, 0, 0, a))
	if banner_t > 0.0:
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		_text(Vector2(vs.x * 0.5, Tower.TOP + 24.0), banner, 16, Color(banner_color, a), true)
	if debug:
		var lines := [
			"FPS %d" % Engine.get_frames_per_second(),
			"enemigos %d" % Game.enemies.size(),
			"sangre %d  gibs %d" % [Game.blood.count(), Game.gibs.gibs.size()],
			"fx %d  balas %d" % [Game.fx.count(), Game.projectiles.bullets.size()],
		]
		for i in lines.size():
			_text(Vector2(12, Tower.TOP + 50 + i * 10), lines[i], 8, Color(0.6, 1, 0.6))

func _panel_idle(top: float) -> void:
	if director and director.idle():
		var r := Rect2(40, top + 12, 280, clampf(_panel_h() * 0.4, 34.0, 70.0))
		var bonus := director.early_bonus()
		_btn(r, "INICIAR OLEADA %d" % (Game.wave + 1), func() -> void: start_wave_requested.emit(), true, Color(0.5, 1, 0.6), "+%d oro · empieza en %ds" % [bonus, ceili(director.countdown)])
		_play_icon(r.position + Vector2(14, r.size.y * 0.5 - 4.0), Color(0.5, 1, 0.6))
	else:
		_text(Vector2(180, top + 30), "Oleada en curso: %d enemigos" % Game.enemies.size(), 8, Color(1, 0.6, 0.55), true)
	top += maxf(0.0, _panel_h() * 0.4 - 34.0)
	_text(Vector2(180, top + 64), "Toca una  X  de la torre para construir una trampa", 8, Color(0.7, 0.7, 0.75), true)
	_text(Vector2(180, top + 78), "Combos: Agua > Tesla · Aceite > Fuego · Pisón empuja atrás", 8, Color(0.5, 0.9, 0.8, 0.8), true)

func _panel_h() -> float:
	return get_viewport_rect().size.y - Tower.BOTTOM - 4.0

func _panel_build(top: float) -> void:
	var traps := Catalog.traps()
	var bw := 84.0
	var bh := clampf((_panel_h() - 20.0) * 0.5, 34.0, 64.0)
	for i in traps.size():
		var t := traps[i]
		var col := i % 4
		var row := i / 4
		var r := Rect2(8 + col * (bw + 2), top + 6 + row * (bh + 4), bw, bh)
		var can := Game.gold >= t.cost
		_btn(r, t.display_name, func() -> void: build_requested.emit(t.id), can, t.color, "%d oro" % t.cost)
	var rc := Rect2(8 + 3 * (bw + 2), top + 6 + bh + 4, bw, bh)
	_btn(rc, "CERRAR", func() -> void: cancel_requested.emit(), true, Color(0.6, 0.6, 0.65))

func _panel_trap(top: float) -> void:
	var t := selected_trap
	_text(Vector2(12, top + 16), "%s  Nv %d" % [t.data.display_name, t.level], 8, t.data.color)
	var kills := "bajas %d" % t.kills
	_text(Vector2(350 - _font.get_string_size(kills, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, top + 16), kills, 8, Color(0.8, 0.8, 0.85))
	_text(Vector2(12, top + 30), t.data.description, 8, Color(0.75, 0.75, 0.8))
	var y := top + 42
	var bh := clampf(_panel_h() - 54.0, 34.0, 64.0)
	if t.level < Trap.MAX_LEVEL:
		var cost := t.upgrade_cost()
		_btn(Rect2(8, y, 140, bh), "MEJORAR", func() -> void: upgrade_requested.emit(), Game.gold >= cost, Color(0.5, 1, 0.6), "%d oro" % cost)
	else:
		_btn(Rect2(8, y, 140, bh), "NIVEL MÁXIMO", func() -> void: pass, false, Color(1, 0.85, 0.3))
	_btn(Rect2(152, y, 110, bh), "VENDER", func() -> void: sell_requested.emit(), true, Color(1, 0.5, 0.4), "+%d oro" % t.sell_value())
	_btn(Rect2(266, y, 86, bh), "CERRAR", func() -> void: cancel_requested.emit(), true, Color(0.6, 0.6, 0.65))
