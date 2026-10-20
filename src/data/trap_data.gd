class_name TrapData
extends Resource
## Definición de una trampa (balance editable como recurso .tres).

enum Behavior { SAW, FLAME, TESLA, SPRINKLER, OIL, TURRET, PISTON }
enum Mount { FLOOR, CEILING }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var behavior: Behavior = Behavior.SAW
@export var mount: Mount = Mount.FLOOR
@export var cost: int = 50
@export var damage: float = 10.0
@export var cooldown: float = 1.0
@export var trap_range: float = 20.0 ## alcance horizontal en px
@export_flags("Fire", "Electric", "Cut", "Blunt", "Water", "Oil") var elements: int = DamageInfo.BLUNT
@export var knockback: float = 0.0
@export var dismember: float = 0.0
@export var chain_count: int = 0
@export var color: Color = Color(1, 0.9, 0.6)
