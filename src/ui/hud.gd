class_name Hud
extends Control
## HUD dibujado a mano (pixel art nítido, cero nodos de UI por elemento).

var banner := ""
var banner_t := 0.0
var banner_color := Color.WHITE
var flash := 0.0
var damage_flash := 0.0
var debug := false
var _font: Font
var _shown_hp := 100.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	Events.wave_started.connect(func(w: int, t: int) -> void: show_banner("OLEADA %d / %d" % [w, t], Color(1, 0.35, 0.35)))
	Events.floor_cleared.connect(func() -> void: show_banner("PISO DESPEJADO — ENTRA AL PORTAL", Color(0.5, 1, 0.7)))
	Events.player_damaged.connect(func(_a: float, _hp: float) -> void: damage_flash = 0.35)
	Events.floor_started.connect(func(i: int) -> void: show_banner("PISO %d — %s" % [i + 1, Layouts.THEMES[i % Layouts.THEMES.size()].name.to_upper()], Color(1, 0.85, 0.5)))

func show_banner(text: String, c: Color) -> void:
	banner = text
	banner_color = c
	banner_t = 2.2

func _process(delta: float) -> void:
	banner_t = maxf(0.0, banner_t - delta)
	damage_flash = maxf(0.0, damage_flash - delta)
	if Game.player:
		_shown_hp = move_toward(_shown_hp, Game.player.hp, delta * 60.0)
	queue_redraw()

func _text(p: Vector2, s: String, size: int, c: Color, center := false) -> void:
	var pos := p
	if center:
		pos.x -= _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	pos = pos.round()
	draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0, 0, 0, c.a))
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _draw() -> void:
	var p := Game.player
	if damage_flash > 0.0:
		var a := damage_flash * 0.5
		draw_rect(Rect2(0, 0, 640, 4), Color(0.8, 0, 0, a))
		draw_rect(Rect2(0, 356, 640, 4), Color(0.8, 0, 0, a))
		draw_rect(Rect2(0, 0, 4, 360), Color(0.8, 0, 0, a))
		draw_rect(Rect2(636, 0, 4, 360), Color(0.8, 0, 0, a))
	if p == null:
		return
	# --- vida
	var bx := 8.0
	var by := 8.0
	draw_rect(Rect2(bx - 1, by - 1, 82, 8), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(bx, by, 80.0 * _shown_hp / p.max_hp, 6), Color(1, 0.9, 0.9))
	draw_rect(Rect2(bx, by, 80.0 * maxf(0.0, p.hp) / p.max_hp, 6), Color(0.85, 0.1, 0.15))
	draw_rect(Rect2(bx, by, 80.0 * maxf(0.0, p.hp) / p.max_hp, 2), Color(1, 0.4, 0.4))
	_text(Vector2(bx + 86, by + 6), "%d" % ceilf(maxf(p.hp, 0.0)), 8, Color.WHITE)
	# --- piso y kills
	_text(Vector2(632 - 90, 14), "PISO %d   BAJAS %d" % [Game.floor_index + 1, Game.kills], 8, Color(1, 0.85, 0.6))
	# --- armas
	var x := 8.0
	for i in p.weapons.size():
		var w := p.weapons[i]
		var sel := i == p.current
		var r := Rect2(x, 334, 22, 18)
		draw_rect(r.grow(1), Color(0, 0, 0, 0.75))
		draw_rect(r, Color(0.2, 0.2, 0.25) if sel else Color(0.08, 0.08, 0.1))
		if sel:
			draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), w.tint())
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), w.tint())
		draw_rect(Rect2(r.position + Vector2(4, 8), Vector2(w.data.length + 2, 3)), w.tint().darkened(0.0 if sel else 0.5))
		var cd := 1.0 - (w._cd * w.rate_mult / w.data.cooldown) if w.data.cooldown > 0.0 else 1.0
		if cd < 1.0:
			draw_rect(Rect2(r.position + Vector2(1, r.size.y - 3), Vector2((r.size.x - 2) * cd, 1)), Color(1, 1, 1, 0.6))
		_text(r.position + Vector2(2, 7), str(i + 1), 8, Color(1, 1, 1, 0.8 if sel else 0.35))
		x += 25.0
	var cw := p.weapon()
	if cw:
		_text(Vector2(x + 4, 347), cw.display_name(), 8, cw.tint())
	# --- banner
	if banner_t > 0.0:
		var a := clampf(banner_t * 2.0, 0.0, 1.0)
		var y := 70.0 - (1.0 - minf(1.0, (2.2 - banner_t) * 6.0)) * 10.0
		_text(Vector2(320, y), banner, 16, Color(banner_color, a), true)
	# --- debug
	if debug:
		var lines := [
			"FPS %d" % Engine.get_frames_per_second(),
			"enemigos %d" % Game.enemies.size(),
			"balas %d" % Game.projectiles.bullets.size(),
			"sangre %d" % Game.blood.count(),
			"gibs %d" % Game.gibs.gibs.size(),
			"fx %d" % Game.fx.count(),
			"zonas %d" % Game.fx.zones.size(),
			"draw calls %d" % Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		]
		for i in lines.size():
			_text(Vector2(8, 30 + i * 10), lines[i], 8, Color(0.6, 1, 0.6))
