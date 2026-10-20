class_name EnemyVisual
extends Node2D
## Placeholder procedural del enemigo, organizado por partes (igual que un sprite
## desmembrable). Para usar arte real: reemplazar este nodo por sprites por parte
## usando part_rect() como anclaje.

var enemy: Enemy
var squash := 0.0
var _was_floor := true

## Rectángulo de cada parte relativo al centro del enemigo (también lo usan los gibs).
func part_rect(part: StringName) -> Rect2:
	var s := enemy.data.size
	var w := s.x
	var h := s.y
	var head := Vector2(roundf(w * 0.75), roundf(h * 0.32))
	var torso_h := roundf(h * 0.4)
	var leg_h := h - head.y - torso_h
	var top := -h * 0.5
	var drop := leg_h if enemy.crawling() else 0.0
	match part:
		&"head": return Rect2(Vector2(-head.x * 0.5 + enemy.facing, top + drop), head)
		&"torso": return Rect2(Vector2(-w * 0.5, top + head.y + drop), Vector2(w, torso_h))
		&"arm_f": return Rect2(Vector2(-1.5 + enemy.facing * w * 0.45, top + head.y + 1 + drop), Vector2(3, torso_h - 1))
		&"arm_b": return Rect2(Vector2(-1.5 - enemy.facing * w * 0.4, top + head.y + 1 + drop), Vector2(3, torso_h - 2))
		&"leg_f": return Rect2(Vector2(-w * 0.35, top + head.y + torso_h), Vector2(roundf(w * 0.3), leg_h))
		&"leg_b": return Rect2(Vector2(w * 0.05, top + head.y + torso_h), Vector2(roundf(w * 0.3), leg_h))
	return Rect2()

func _process(delta: float) -> void:
	squash = move_toward(squash, 0.0, delta * 2.0)
	var on_floor := enemy.on_ground()
	if on_floor and not _was_floor:
		squash = 0.2
	_was_floor = on_floor

func _draw() -> void:
	var e := enemy
	var d := e.data
	var sp := clampf(1.0 - e.spawning / 0.55, 0.0, 1.0)
	var feet := d.size.y * 0.5
	var sy := (1.0 - squash) * sp
	var sx := 1.0 + squash * 0.6
	var jitter := Vector2.ZERO
	if e.shock_fx > 0.0 or e.stun > 0.0:
		jitter = Vector2(Game.rng.randi_range(-1, 1), 0)
	draw_set_transform(Vector2(0, feet * (1.0 - sy)) + jitter, 0.0, Vector2(sx, sy))

	var skin := d.skin
	var cloth := d.cloth
	if e.wet > 0.0:
		skin = skin.lerp(Color(0.3, 0.5, 0.9), 0.3)
		cloth = cloth.lerp(Color(0.2, 0.3, 0.6), 0.3)
	if e.oiled > 0.0:
		skin = skin.darkened(0.45)
		cloth = cloth.darkened(0.45)
	if e.char_amount > 0.0:
		skin = skin.lerp(Color(0.12, 0.08, 0.07), e.char_amount * 0.8)
		cloth = cloth.lerp(Color(0.08, 0.06, 0.06), e.char_amount * 0.8)
	var white := e.flash > 0.0 or (e.stun > 0.0 and Engine.get_process_frames() % 6 < 2)
	if white:
		skin = Color(1, 1, 1)
		cloth = Color(0.9, 0.95, 1.0)
	if sp < 1.0:
		skin = skin.lerp(Color(0.6, 0.1, 0.4), 1.0 - sp)
		cloth = cloth.lerp(Color(0.4, 0.05, 0.3), 1.0 - sp)

	var stump := d.blood.lightened(0.15)
	var bob := 0.0 if e.crawling() else roundf(sin(e.walk_phase) * 0.6)
	var stride := sin(e.walk_phase) * 2.0

	# piernas
	for k in [&"leg_b", &"leg_f"]:
		var r := part_rect(k)
		if e.parts[k]:
			var lift := stride if k == &"leg_f" else -stride
			var rr := Rect2(r.position + Vector2(roundf(lift * 0.5), minf(0.0, -absf(lift) * 0.5)), r.size)
			draw_rect(rr, cloth.darkened(0.35 if k == &"leg_b" else 0.15))
			draw_rect(Rect2(rr.position + Vector2(0, rr.size.y - 1), Vector2(rr.size.x + 1, 1)), cloth.darkened(0.6))
		elif not e.crawling():
			draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), stump)
	# brazo trasero
	_arm(&"arm_b", skin.darkened(0.25), stump, bob)
	# torso
	var t := part_rect(&"torso")
	t.position.y += bob
	draw_rect(t, cloth)
	draw_rect(Rect2(t.position + Vector2(t.size.x * 0.5 - e.facing * t.size.x * 0.5 - (1 if e.facing < 0 else 0), 0), Vector2(1, t.size.y)), cloth.darkened(0.35))
	draw_rect(Rect2(t.position + Vector2(0, t.size.y - 2), Vector2(t.size.x, 1)), cloth.darkened(0.45))
	match d.id:
		&"bloater":
			var belly := Rect2(t.position + Vector2(-2, 1), t.size + Vector2(4, 1))
			draw_rect(belly, skin.darkened(0.1))
			draw_rect(Rect2(belly.position + Vector2(3, 2), Vector2(2, 2)), Color(0.8, 0.85, 0.3))
			draw_rect(Rect2(belly.position + Vector2(belly.size.x - 6, 4), Vector2(2, 1)), Color(0.8, 0.85, 0.3))
		&"brute":
			draw_rect(Rect2(t.position + Vector2(-2, 0), Vector2(t.size.x + 4, 4)), cloth.lightened(0.1))
			draw_rect(Rect2(t.position + Vector2(2, 5), Vector2(t.size.x - 4, 1)), Color(0.5, 0.45, 0.4))
	if e.parts[&"head"]:
		var h := part_rect(&"head")
		h.position.y += bob
		draw_rect(h, skin)
		draw_rect(Rect2(h.position + Vector2(0, h.size.y - 1), Vector2(h.size.x, 1)), skin.darkened(0.3))
		var ex: float = h.position.x + (h.size.x - 3.0 if e.facing > 0 else 1.0)
		var eye := d.eye if not white else Color.WHITE
		draw_rect(Rect2(ex, h.position.y + 2, 2, 1), eye)
		draw_rect(Rect2(ex - e.facing * 2, h.position.y + h.size.y - 3, 3, 1), Color(0.15, 0.02, 0.04))
		if e.hp < e.data.hp * 0.5:
			draw_rect(Rect2(h.position + Vector2(1, 1), Vector2(1, 2)), d.blood)
	else:
		var n := part_rect(&"torso").position + Vector2(d.size.x * 0.5 - 2, bob - 2)
		draw_rect(Rect2(n, Vector2(4, 2)), stump)
		draw_rect(Rect2(n + Vector2(1, -1), Vector2(2, 1)), stump.lightened(0.2))
	_arm(&"arm_f", skin, stump, bob)
	if e.oiled > 0.0 and not white:
		draw_rect(Rect2(t.position + Vector2(1, 1), Vector2(1, 1)), Color(0.8, 0.75, 0.5))
	draw_set_transform(Vector2.ZERO)

func _arm(k: StringName, c: Color, stump: Color, bob: float) -> void:
	var r := part_rect(k)
	r.position.y += bob
	if enemy.parts[k]:
		# brazos extendidos al frente (zombi) que se balancean
		var reach := roundf(2.0 + sin(enemy.walk_phase * 0.5 + (0.0 if k == &"arm_f" else 1.5)) * 1.5)
		var arm := Rect2(r.position + Vector2(0 if enemy.facing > 0 else -reach, 1), Vector2(r.size.x + reach, 2))
		draw_rect(arm, c)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 3)), c.darkened(0.15))
	else:
		draw_rect(Rect2(r.position, Vector2(2, 2)), stump)
