extends Node
## Bus global de señales. Los sistemas emiten aquí y otros escuchan,
## sin referencias directas entre ellos (shake, hitstop, UI, audio...).

signal screen_shake(trauma: float)
signal hitstop(duration: float)
signal enemy_killed(enemy: Node2D, info: DamageInfo)
signal enemy_spawned(enemy: Node2D)
signal enemy_leaked(enemy: Node2D, lives_lost: int)
signal gold_changed(gold: int)
signal wave_started(wave: int, total: int)
signal wave_cleared(wave: int, bonus: int)
signal game_over(victory: bool)
signal reaction(name: String, pos: Vector2)
