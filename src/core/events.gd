extends Node
## Bus global de señales. Los sistemas emiten aquí y otros escuchan,
## sin referencias directas entre ellos (shake, hitstop, UI, audio...).

signal screen_shake(trauma: float)
signal hitstop(duration: float)
signal enemy_killed(enemy: Node2D, info: DamageInfo)
signal enemy_spawned(enemy: Node2D)
signal player_damaged(amount: float, hp: float)
signal player_died
signal weapon_changed(index: int)
signal inventory_changed
signal wave_started(wave: int, total: int)
signal floor_cleared
signal floor_started(floor_index: int)
signal reaction(name: String, pos: Vector2)
