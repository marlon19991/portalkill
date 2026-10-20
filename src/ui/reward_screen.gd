class_name RewardScreen
extends Control
## Elige 1 de 3 recompensas entre pisos: arma nueva, mejora, infusión elemental o vida.

signal chosen

var options: Array[Dictionary] = []
var _font: Font
var _t := 0.0
var _hover := -1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	visible = false

func open(p: Player) -> void:
	options = _roll(p)
	_t = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

func _roll(p: Player) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var unowned: Array = []
	for id in Catalog.weapon_ids():
		if not p.has_weapon(id):
			unowned.append(id)
	unowned.shuffle()
	if not unowned.is_empty():
		var d := Catalog.weapon(unowned[0])
		out.append({kind = "weapon", id = d.id, title = d.display_name, desc = d.description, color = d.color, tag = "ARMA NUEVA"})
	# infusión elemental en un arma que ya tienes
	var elems := [DamageInfo.FIRE, DamageInfo.ELECTRIC, DamageInfo.CUT]
	var tries := 10
	while out.size() < 2 and tries > 0:
		tries -= 1
		var w: Weapon = p.weapons[Game.rng.randi() % p.weapons.size()]
		var e: int = elems[Game.rng.randi() % elems.size()]
		if w.elements() & e:
			continue
		out.append({kind = "infuse", weapon = w, element = e, title = "%s + %s" % [w.data.display_name, DamageInfo.element_name(e)],
			desc = "Infusión: el arma aplica %s." % DamageInfo.element_name(e).to_lower(), color = DamageInfo.element_color(e), tag = "INFUSIÓN"})
	while out.size() < 3:
		if Game.rng.randf() < 0.35:
			out.append({kind = "heal", title = "Sangre fresca", desc = "+40 vida y +10 vida máxima.", color = Color(0.9, 0.2, 0.25), tag = "VIDA"})
		else:
			var w: Weapon = p.weapons[Game.rng.randi() % p.weapons.size()]
			out.append({kind = "upgrade", weapon = w, title = "%s +%d" % [w.data.display_name, w.level], desc = "+30% daño, +15% cadencia.", color = w.tint(), tag = "MEJORA"})
	return out

func _apply(i: int) -> void:
	var o := options[i]
	var p := Game.player
	match o.kind:
		"weapon":
			p.add_weapon(Catalog.weapon(o.id))
			p.select(p.weapons.size() - 1)
		"infuse":
			o.weapon.extra_elements |= o.element
		"upgrade":
			o.weapon.damage_mult *= 1.3
			o.weapon.rate_mult *= 1.15
			o.weapon.level += 1
		"heal":
			p.max_hp += 10.0
			p.heal(40.0)
	Events.inventory_changed.emit()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	chosen.emit()

func _card_rect(i: int) -> Rect2:
	return Rect2(80 + i * 165, 110, 150, 150)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if Game.autotest and _t > 1.2:
		_apply(0)
		return
	_hover = -1
	var m := get_local_mouse_position()
	for i in options.size():
		if _card_rect(i).has_point(m):
			_hover = i
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _t < 0.4:
		return
	for i in options.size():
		if event.is_action_pressed("weapon_%d" % (i + 1)):
			_apply(i)
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
		_apply(_hover)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(0.02, 0.0, 0.03, minf(0.85, _t * 3.0)))
	_txt(Vector2(320, 70), "ELIGE TU RECOMPENSA", 16, Color(1, 0.85, 0.5), true)
	for i in options.size():
		var o := options[i]
		var r := _card_rect(i)
		var rise := (1.0 - minf(1.0, maxf(0.0, _t * 4.0 - i * 0.4))) * 30.0
		r.position.y += rise - (4.0 if _hover == i else 0.0)
		var c: Color = o.color
		draw_rect(r.grow(2), Color(0, 0, 0, 0.9))
		draw_rect(r, Color(0.09, 0.07, 0.11))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), c)
		draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), c.darkened(0.4))
		if _hover == i:
			draw_rect(r.grow(1), Color(c, 0.6), false, 1.0)
		_txt(r.position + Vector2(75, 22), o.tag, 8, Color(c, 0.9), true)
		# icono
		var ic := r.position + Vector2(55, 40)
		draw_rect(Rect2(ic, Vector2(40, 30)), Color(0.04, 0.03, 0.05))
		draw_rect(Rect2(ic + Vector2(8, 13), Vector2(24, 5)), c)
		draw_rect(Rect2(ic + Vector2(8, 13), Vector2(24, 1)), c.lightened(0.4))
		_txt(r.position + Vector2(75, 92), o.title, 8, Color.WHITE, true)
		_wrap(r.position + Vector2(10, 110), o.desc, 130.0, Color(0.75, 0.75, 0.8))
		_txt(r.position + Vector2(75, 144), "[%d]" % (i + 1), 8, Color(1, 1, 1, 0.5), true)

func _txt(p: Vector2, s: String, size: int, c: Color, center := false) -> void:
	var pos := p
	if center:
		pos.x -= _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string_outline(_font, pos.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color.BLACK)
	draw_string(_font, pos.round(), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _wrap(p: Vector2, s: String, width: float, c: Color) -> void:
	draw_multiline_string(_font, p.round(), s, HORIZONTAL_ALIGNMENT_CENTER, width, 8, -1, c)
