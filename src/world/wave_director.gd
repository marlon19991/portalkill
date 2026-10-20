class_name WaveDirector
extends Node
## Oleadas por presupuesto: cada oleada "compra" enemigos según su costo.
## Entre oleadas hay cuenta regresiva; empezar antes da oro extra.

signal spawn_requested(data: EnemyData, wave: int)
signal all_waves_cleared

const FIRST_DELAY := 20.0
const BETWEEN := 12.0

var countdown := FIRST_DELAY
var spawning := false
var finished := false
var _queue: Array[EnemyData] = []
var _spawn_timer := 0.0

func reset() -> void:
	countdown = FIRST_DELAY
	spawning = false
	finished = false
	_queue.clear()

func idle() -> bool:
	return not spawning and not finished and countdown > 0.0

func early_bonus() -> int:
	return int(countdown * 1.5)

## Inicia la siguiente oleada ya (botón ▶). Devuelve el bono ganado.
func start_now() -> int:
	if not idle():
		return 0
	var bonus := early_bonus()
	Game.add_gold(bonus)
	_next_wave()
	return bonus

func _process(delta: float) -> void:
	if finished:
		return
	if spawning:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and not _queue.is_empty():
			spawn_requested.emit(_queue.pop_front(), Game.wave)
			_spawn_timer = 0.05 if Game.stress else (0.35 if Game.rng.randf() < 0.5 else Game.rng.randf_range(0.8, 1.6))
		if _queue.is_empty():
			spawning = false
			countdown = -1.0 # esperar a que mueran todos
		return
	if countdown < 0.0:
		if Game.enemies.is_empty():
			var bonus := 15 + Game.wave * 5
			Game.add_gold(bonus)
			Events.wave_cleared.emit(Game.wave, bonus)
			if Game.wave >= Game.TOTAL_WAVES:
				finished = true
				all_waves_cleared.emit()
				return
			countdown = BETWEEN
		return
	countdown -= delta
	if countdown <= 0.0:
		_next_wave()

func _next_wave() -> void:
	Game.wave += 1
	var w := Game.wave
	var budget := int(5 + w * 3.5 + pow(w, 1.45))
	if Game.stress:
		budget *= 8
	var pool: Array[EnemyData] = []
	for e in Catalog.enemies():
		if e.min_wave <= w:
			pool.append(e)
	while budget > 0:
		var pick: EnemyData = pool[Game.rng.randi() % pool.size()]
		if pick.cost > budget:
			pick = pool[0]
		_queue.append(pick)
		budget -= pick.cost
		if pick.id == &"runner" and budget > 1:
			_queue.append(pick)
			budget -= 1
	spawning = true
	countdown = 0.0
	_spawn_timer = 0.2
	Events.wave_started.emit(w, Game.TOTAL_WAVES)
