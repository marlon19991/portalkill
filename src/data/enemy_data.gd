class_name EnemyData
extends Resource
## Definición de un tipo de enemigo.

enum DeathEffect { NONE, OIL_BURST }

@export var id: StringName
@export var display_name: String
@export var hp: float = 30.0
@export var speed: float = 22.0 ## px/s a lo largo de la ruta
@export var size: Vector2 = Vector2(10, 16)
@export var cost: int = 1
@export var min_wave: int = 1
@export var bounty: int = 5 ## oro por baja
@export var lives_cost: int = 1 ## vidas que quita si llega al final
@export var knockback_resist: float = 0.0
@export var skin: Color = Color(0.55, 0.62, 0.45)
@export var cloth: Color = Color(0.3, 0.22, 0.25)
@export var eye: Color = Color(1, 0.2, 0.1)
@export var blood: Color = Color(0.6, 0.02, 0.05)
@export var death_effect: DeathEffect = DeathEffect.NONE
## Multiplicadores de daño por elemento (bit → mult).
@export var resist: Dictionary = {}
