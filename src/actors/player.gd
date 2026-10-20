class_name Player
extends CharacterBody2D
## Jugador: movimiento con "game feel" (coyote time, buffer de salto, salto variable),
## inventario de armas y apuntado con ratón / stick derecho / bot de autotest.

const SIZE := Vector2(8, 14)
const MAX_SPEED := 135.0
const ACCEL := 1500.0
const AIR_ACCEL := 1000.0
const FRICTION := 1800.0
const GRAVITY_UP := 900.0
const GRAVITY_DOWN := 1500.0
const JUMP_VEL := 330.0
const COYOTE := 0.1
const BUFFER := 0.12
const MAX_WEAPONS := 6

var max_hp := 100.0
var hp := 100.0
var dead := false
var weapons: Array[Weapon] = []
var current := 0
var aim := Vector2.RIGHT
var god := false

var _coyote := 0.0
var _buffer := 0.0
var _drop_t := 0.0
var _iframes := 0.0
var _kick := 0.0
var _squash := 0.0
var _walk := 0.0
var _was_floor := true
var _bot_t := 0.0
var _bot_exit_t := 0.0
var _glow: GlowLayer

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_snap_length = 3.0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = SIZE
	cs.shape = sh
	add_child(cs)
	_glow = GlowLayer.new(_draw_glow)
	add_child(_glow)

func reset_loadout() -> void:
	weapons.clear()
	add_weapon(Catalog.weapon(&"pistol"))
	add_weapon(Catalog.weapon(&"machete"))
	current = 0
	max_hp = 100.0
	hp = max_hp
	dead = false

func add_weapon(d: WeaponData) -> Weapon:
	var w := Weapon.new(d)
	if weapons.size() < MAX_WEAPONS:
		weapons.append(w)
	else:
		weapons[current] = w
	Events.inventory_changed.emit()
	return w

func has_weapon(id: StringName) -> bool:
	for w in weapons:
		if w.data.id == id:
			return true
	return false

func weapon() -> Weapon:
	return weapons[current] if current < weapons.size() else null

func center() -> Vector2:
	return global_position

func hit_rect() -> Rect2:
	return Rect2(global_position - SIZE * 0.5, SIZE)

func muzzle() -> Vector2:
	var w := weapon()
	var l := w.data.length if w else 6.0
	return center() + Vector2(0, -1) + aim * (l + 2.0)

func hurt(amount: float, dir: Vector2) -> void:
	if dead or _iframes > 0.0 or god:
		return
	hp -= amount
	_iframes = 0.8
	velocity = dir * 200.0 + Vector2(0, -120)
	Game.blood.burst(center(), dir, int(10 * Game.gore_mult()), Color(0.7, 0.05, 0.08))
	Events.screen_shake.emit(0.4)
	Events.hitstop.emit(0.08)
	Events.player_damaged.emit(amount, hp)
	if hp <= 0.0:
		dead = true
		Game.blood.burst(center(), Vector2.UP, int(60 * Game.gore_mult()), Color(0.7, 0.05, 0.08))
		visible = false
		Events.player_died.emit()

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)

func select(i: int) -> void:
	if i >= 0 and i < weapons.size() and i != current:
		current = i
		Events.weapon_changed.emit(i)

func _physics_process(delta: float) -> void:
	if dead:
		return
	_iframes = maxf(0.0, _iframes - delta)
	_kick = move_toward(_kick, 0.0, delta * 30.0)
	_squash = move_toward(_squash, 0.0, delta * 2.5)
	for w in weapons:
		w.tick(delta)

	var input_x: float
	var jump_pressed: bool
	var jump_held: bool
	var down: bool
	var firing: bool
	if Game.autotest:
		var bot := _bot(delta)
		input_x = bot.x
		jump_pressed = bot.y > 0.5
		jump_held = jump_pressed
		down = bot.y < -0.5
		firing = true
	else:
		input_x = Input.get_axis("move_left", "move_right")
		jump_pressed = Input.is_action_just_pressed("jump")
		jump_held = Input.is_action_pressed("jump")
		down = Input.is_action_pressed("move_down")
		firing = Input.is_action_pressed("fire")
		_update_aim()
		if Input.is_action_just_pressed("next_weapon"):
			select((current + 1) % weapons.size())
		if Input.is_action_just_pressed("prev_weapon"):
			select((current - 1 + weapons.size()) % weapons.size())
		for i in weapons.size():
			if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
				select(i)

	# --- movimiento horizontal
	var on_floor := is_on_floor()
	var target := input_x * MAX_SPEED
	var a := ACCEL if on_floor else AIR_ACCEL
	if absf(input_x) < 0.1:
		a = FRICTION if on_floor else AIR_ACCEL * 0.5
	velocity.x = move_toward(velocity.x, target, a * delta)

	# --- salto con coyote time + buffer + salto variable
	_coyote = COYOTE if on_floor else _coyote - delta
	_buffer = BUFFER if jump_pressed else _buffer - delta
	if _buffer > 0.0 and _coyote > 0.0:
		if down and _on_oneway():
			set_collision_mask_value(2, false)
			_drop_t = 0.22
		else:
			velocity.y = -JUMP_VEL
			_squash = -0.3
			Game.fx.dust(center() + Vector2(0, SIZE.y * 0.5), 5)
		_buffer = 0.0
		_coyote = 0.0
	if _drop_t > 0.0:
		_drop_t -= delta
		if _drop_t <= 0.0:
			set_collision_mask_value(2, true)
	if not jump_held and velocity.y < -120.0:
		velocity.y = -120.0
	var g := GRAVITY_UP if velocity.y < 0.0 else GRAVITY_DOWN
	velocity.y = minf(velocity.y + g * delta, 420.0)

	# --- disparo
	var w := weapon()
	if firing and w and w.ready_to_fire():
		var recoil := w.fire(muzzle(), aim)
		velocity.x += recoil.x
		if not on_floor:
			velocity.y += recoil.y * 0.5
		_kick = 3.0 if w.data.recoil > 50.0 else 1.5

	move_and_slide()
	if is_on_floor() and not _was_floor:
		_squash = 0.25
		Game.fx.dust(center() + Vector2(0, SIZE.y * 0.5), 4)
	_was_floor = is_on_floor()
	_walk += absf(velocity.x) * delta * 0.25
	queue_redraw()
	_glow.queue_redraw()

func _on_oneway() -> bool:
	var feet := center() + Vector2(0, SIZE.y * 0.5 + 2.0)
	return Game.level.cell(int(feet.x / Level.TILE), int(feet.y / Level.TILE)) == Level.ONEWAY

func _update_aim() -> void:
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > 0.35:
		aim = stick.normalized()
	else:
		var to := get_global_mouse_position() - center()
		if to.length() > 2.0:
			aim = to.normalized()

## Bot simple para autotest/demo: apunta al más cercano, mantiene distancia y salta.
func _bot(delta: float) -> Vector2:
	_bot_t -= delta
	var nearest: Enemy = null
	var nd := INF
	for e in Game.enemies:
		if e.spawning > 0.0:
			continue
		var d := e.center().distance_to(center())
		if d < nd:
			nd = d
			nearest = e
	var jump := 0.0
	var mx := 0.0
	if nearest:
		aim = (nearest.center() - center()).normalized()
		var dx := nearest.center().x - center().x
		mx = -signf(dx) if nd < 50.0 else signf(dx) * 0.4
		if nd < 40.0 and Game.rng.randf() < 0.05:
			jump = 1.0
	elif Game.level and Game.exit_open:
		# el bot no sabe trepar: tras unos segundos salta al portal (solo autotest)
		_bot_exit_t += delta
		if _bot_exit_t > 5.0:
			_bot_exit_t = 0.0
			global_position = Game.level.exit_pos
			print("[autotest] bot -> portal de salida")
		var dx := Game.level.exit_pos.x - center().x
		var dy := Game.level.exit_pos.y - center().y
		mx = signf(dx) if absf(dx) > 6.0 else 0.0
		if dy < -10.0 and Game.rng.randf() < 0.08:
			jump = 1.0
		if dy > 10.0 and Game.rng.randf() < 0.05:
			jump = -1.0
	if _bot_t <= 0.0:
		_bot_t = 4.0
		select((current + 1) % weapons.size())
	if is_on_wall():
		jump = 1.0
	return Vector2(mx, jump)

func _draw() -> void:
	var blink := _iframes > 0.0 and Engine.get_process_frames() % 6 < 3
	if blink:
		return
	var sy := 1.0 - _squash
	var sx := 1.0 + _squash * 0.6
	var f := 1.0 if aim.x >= 0.0 else -1.0
	draw_set_transform(Vector2(0, SIZE.y * 0.5 * (1.0 - sy)), 0.0, Vector2(sx, sy))
	var suit := Color(0.18, 0.2, 0.26)
	var armor := Color(0.55, 0.58, 0.62)
	var visor := Color(0.4, 1.0, 0.85)
	var on_floor := is_on_floor()
	var stride := sin(_walk) * 2.0 if on_floor and absf(velocity.x) > 10.0 else 0.0
	# piernas
	draw_rect(Rect2(Vector2(-3 + roundf(stride * 0.5), 2), Vector2(3, 5)), suit.darkened(0.2))
	draw_rect(Rect2(Vector2(0 - roundf(stride * 0.5), 2), Vector2(3, 5)), suit)
	draw_rect(Rect2(Vector2(-3 + roundf(stride * 0.5), 6), Vector2(3, 1)), Color(0.1, 0.1, 0.12))
	draw_rect(Rect2(Vector2(0 - roundf(stride * 0.5), 6), Vector2(3, 1)), Color(0.1, 0.1, 0.12))
	# torso + capa
	var cape_wave := roundf(sin(_walk * 0.5 + Time.get_ticks_msec() * 0.004) * 1.0)
	draw_rect(Rect2(Vector2(-f * 4 - (2 if f > 0 else 0) , -3), Vector2(2, 8 + cape_wave)), Color(0.55, 0.08, 0.12))
	draw_rect(Rect2(Vector2(-4, -3), Vector2(8, 6)), armor)
	draw_rect(Rect2(Vector2(-4, 1), Vector2(8, 1)), armor.darkened(0.4))
	draw_rect(Rect2(Vector2(-f * 3 - 0.5, -2), Vector2(1, 4)), armor.darkened(0.25))
	# casco
	draw_rect(Rect2(Vector2(-3, -8), Vector2(7, 5)), armor.lightened(0.1))
	draw_rect(Rect2(Vector2(-3, -8), Vector2(7, 1)), armor.lightened(0.3))
	draw_rect(Rect2(Vector2(f * 1 - 1 + (1 if f > 0 else -1), -6), Vector2(3, 2)), visor)
	draw_set_transform(Vector2.ZERO)
	# arma rotada hacia la mira
	var w := weapon()
	if w:
		var l := w.data.length
		draw_set_transform(Vector2(0, -1) - aim * _kick, aim.angle(), Vector2(1, f))
		var c := w.tint()
		match w.data.behavior:
			WeaponData.Behavior.MELEE:
				draw_rect(Rect2(1, -1, 3, 2), Color(0.3, 0.2, 0.15))
				draw_rect(Rect2(4, -2, l - 3, 3), c)
				draw_rect(Rect2(4, -2, l - 3, 1), c.lightened(0.4))
			WeaponData.Behavior.THROW:
				draw_rect(Rect2(3, -2, 3, 4), Color(0.35, 0.55, 0.3))
				draw_rect(Rect2(6, -1, 2, 2), Color(0.85, 0.8, 0.6))
			_:
				draw_rect(Rect2(2, -1, l, 3), Color(0.22, 0.22, 0.26))
				draw_rect(Rect2(2, -1, l, 1), c.darkened(0.2))
				draw_rect(Rect2(l, -1, 2, 2), c)
				draw_rect(Rect2(3, 1, 2, 2), Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(1, -1, 2, 2), armor) # mano
		draw_set_transform(Vector2.ZERO)

func _draw_glow(ci: Node2D) -> void:
	if dead:
		return
	var f := 1.0 if aim.x >= 0.0 else -1.0
	Pixel.glow(ci, Vector2(f * 1.5, -5), 7.0, Color(0.3, 1.0, 0.8, 0.5))
	var w := weapon()
	if w and w.extra_elements:
		Pixel.glow(ci, Vector2(0, -1) + aim * w.data.length, 6.0, Color(w.tint(), 0.6))
