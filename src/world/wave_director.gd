class_name WaveDirector
extends Node
## Director de oleadas por presupuesto: cada oleada "compra" enemigos según su costo.

signal spawn_requested(data: EnemyData)
signal all_waves_cleared

var floor_index := 0
var wave := 0
var total_waves := 3
var _queue: Array[EnemyData] = []
var _spawn_timer := 0.0
var _between := 0.0
var _active := false
var _alive_cap := 30

func start(floor_: int) -> void:
	floor_index = floor_
	wave = 0
	total_waves = mini(3 + floor_ / 2, 7)
	_alive_cap = 26 + floor_ * 6
	if Game.stress:
		_alive_cap = 140
	_active = true
	_between = 1.5
	_queue.clear()

func stop() -> void:
	_active = false
	_queue.clear()

func _process(delta: float) -> void:
	if not _active:
		return
	if not _queue.is_empty():
		_spawn_timer -= delta
		if _spawn_timer <= 0.0 and Game.enemies.size() < _alive_cap:
			spawn_requested.emit(_queue.pop_front())
			# ráfagas: a veces varios seguidos, a veces pausa
			_spawn_timer = 0.02 if Game.stress else (0.12 if Game.rng.randf() < 0.45 else Game.rng.randf_range(0.4, 0.9))
		return
	if Game.enemies.is_empty():
		if wave >= total_waves:
			_active = false
			all_waves_cleared.emit()
			return
		_between -= delta
		if _between <= 0.0:
			_next_wave()

func _next_wave() -> void:
	wave += 1
	_between = 2.0
	var budget := 5 + floor_index * 4 + wave * 3
	if Game.stress:
		budget *= 10
	var pool: Array[EnemyData] = []
	for e in Catalog.enemies():
		if e.min_floor <= floor_index:
			pool.append(e)
	while budget > 0:
		var pick: EnemyData = pool[Game.rng.randi() % pool.size()]
		if pick.cost > budget:
			pick = pool[0]
		_queue.append(pick)
		budget -= pick.cost
		# grupos de corredores
		if pick.id == &"runner" and budget > 1:
			_queue.append(pick)
			budget -= 1
	_spawn_timer = 0.3
	Events.wave_started.emit(wave, total_waves)
