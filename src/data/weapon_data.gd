class_name WeaponData
extends Resource
## Definición de un arma (balance editable como recurso .tres).

enum Behavior { PROJECTILE, MELEE, THROW, CHAIN, STREAM }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var behavior: Behavior = Behavior.PROJECTILE
@export var damage: float = 10.0
@export var cooldown: float = 0.25
@export_flags("Fire", "Electric", "Cut", "Blunt", "Water", "Oil") var elements: int = DamageInfo.BLUNT
@export var speed: float = 420.0
@export var spread: float = 0.04
@export var pellets: int = 1
@export var weapon_range: float = 24.0
@export var knockback: float = 80.0
@export var dismember: float = 0.0
@export var gravity: float = 0.0
@export var pierce: int = 0
@export var chain_count: int = 3
@export var recoil: float = 20.0
@export var shake: float = 0.08
@export var color: Color = Color(1, 0.9, 0.6)
@export var length: float = 9.0 ## largo visual del arma en px
