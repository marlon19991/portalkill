extends Node
## Estado global de la partida (oro, vidas, oleada) y ajustes.

enum Gore { OFF, NORMAL, EXTREME }

const START_GOLD := 160
const START_LIVES := 20
const TOTAL_WAVES := 12

var gore: int = Gore.NORMAL
var gold: int = START_GOLD
var lives: int = START_LIVES
var wave: int = 0
var kills: int = 0
var autotest: bool = false
var stress: bool = false ## prueba de carga: muchas más hordas
var rng := RandomNumberGenerator.new()

## Referencias del nivel actual (las registra main.gd). Acceso O(1) para sistemas.
var level: Tower
var blood: BloodSystem
var gibs: GibSystem
var fx: FxSystem
var projectiles: ProjectileSystem
var enemies: Array[Enemy] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	autotest = "--autotest" in OS.get_cmdline_user_args()

func reset_run() -> void:
	gold = START_GOLD
	lives = START_LIVES
	wave = 0
	kills = 0

func gore_mult() -> float:
	match gore:
		Gore.OFF: return 0.0
		Gore.EXTREME: return 2.2
	return 1.0

func add_gold(n: int) -> void:
	gold += n
	Events.gold_changed.emit(gold)

func spend(n: int) -> bool:
	if gold < n:
		return false
	gold -= n
	Events.gold_changed.emit(gold)
	return true
