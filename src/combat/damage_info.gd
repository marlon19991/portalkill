class_name DamageInfo
extends RefCounted
## Descripción de un golpe. Todas las armas y peligros producen uno.

const FIRE := 1
const ELECTRIC := 2
const CUT := 4
const BLUNT := 8
const WATER := 16
const OIL := 32

var amount: float = 10.0
var elements: int = BLUNT
var dir: Vector2 = Vector2.RIGHT
var knockback: float = 80.0
var dismember: float = 0.0
var from_player: bool = true

static func make(amount_: float, elements_: int, dir_: Vector2, knockback_: float = 80.0, dismember_: float = 0.0) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = amount_
	d.elements = elements_
	d.dir = dir_
	d.knockback = knockback_
	d.dismember = dismember_
	return d

func copy() -> DamageInfo:
	var d := DamageInfo.make(amount, elements, dir, knockback, dismember)
	d.from_player = from_player
	return d

func has(e: int) -> bool:
	return elements & e != 0

static func element_color(e: int) -> Color:
	if e & FIRE: return Color(1.0, 0.55, 0.15)
	if e & ELECTRIC: return Color(0.55, 0.85, 1.0)
	if e & WATER: return Color(0.3, 0.6, 1.0)
	if e & CUT: return Color(0.95, 0.2, 0.25)
	if e & OIL: return Color(0.35, 0.3, 0.2)
	return Color(1.0, 0.95, 0.7)

static func element_name(e: int) -> String:
	match e:
		FIRE: return "Fuego"
		ELECTRIC: return "Electricidad"
		CUT: return "Corte"
		BLUNT: return "Impacto"
		WATER: return "Agua"
		OIL: return "Aceite"
	return "?"
