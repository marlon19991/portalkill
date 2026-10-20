extends Node
## Estado global de la partida y ajustes. También registra el InputMap
## por código para no depender de un project.godot gigante.

enum Gore { OFF, NORMAL, EXTREME }

var gore: int = Gore.NORMAL
var floor_index: int = 0
var kills: int = 0
var autotest: bool = false
var stress: bool = false ## prueba de carga: muchas más hordas
var rng := RandomNumberGenerator.new()

## Referencias del piso actual (las registra main.gd). Acceso O(1) para sistemas.
var level: Level
var player: Player
var blood: BloodSystem
var gibs: GibSystem
var fx: FxSystem
var projectiles: ProjectileSystem
var enemies: Array[Enemy] = []
var exit_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	autotest = "--autotest" in OS.get_cmdline_user_args()
	_setup_input()

func reset_run() -> void:
	floor_index = 0
	kills = 0

func gore_mult() -> float:
	match gore:
		Gore.OFF: return 0.0
		Gore.EXTREME: return 2.2
	return 1.0

func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT], [], JOY_AXIS_LEFT_X, -1.0)
	_bind("move_right", [KEY_D, KEY_RIGHT], [], JOY_AXIS_LEFT_X, 1.0)
	_bind("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_bind("jump", [KEY_W, KEY_SPACE, KEY_UP], [JOY_BUTTON_A])
	_bind("fire", [], [], JOY_AXIS_TRIGGER_RIGHT, 1.0, MOUSE_BUTTON_LEFT)
	_bind("next_weapon", [KEY_E], [JOY_BUTTON_RIGHT_SHOULDER], -1, 0.0, MOUSE_BUTTON_WHEEL_DOWN)
	_bind("prev_weapon", [KEY_Q], [JOY_BUTTON_LEFT_SHOULDER], -1, 0.0, MOUSE_BUTTON_WHEEL_UP)
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_bind("toggle_gore", [KEY_G], [JOY_BUTTON_BACK])
	_bind("debug", [KEY_F3], [])
	_bind("restart", [KEY_R], [JOY_BUTTON_Y])
	for i in 6:
		_bind("weapon_%d" % (i + 1), [KEY_1 + i], [])

func _bind(action: String, keys: Array, buttons: Array, axis: int = -1, axis_dir: float = 0.0, mouse: int = -1) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)
	if axis >= 0:
		var m := InputEventJoypadMotion.new()
		m.axis = axis
		m.axis_value = axis_dir
		InputMap.action_add_event(action, m)
	if mouse >= 0:
		var mb := InputEventMouseButton.new()
		mb.button_index = mouse
		InputMap.action_add_event(action, mb)
