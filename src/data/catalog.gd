class_name Catalog
extends RefCounted
## Catálogo central de contenido. Se construye por código; cada entrada es un
## Resource y se puede guardar como .tres para editarla en el inspector.

static var _traps: Array[TrapData] = []
static var _enemies: Array[EnemyData] = []

static func traps() -> Array[TrapData]:
	if _traps.is_empty():
		_build_traps()
	return _traps

static func trap(id: StringName) -> TrapData:
	for t in traps():
		if t.id == id:
			return t
	return null

static func enemies() -> Array[EnemyData]:
	if _enemies.is_empty():
		_build_enemies()
	return _enemies

static func _t(props: Dictionary) -> void:
	var t := TrapData.new()
	for k in props:
		t.set(k, props[k])
	_traps.append(t)

static func _build_traps() -> void:
	const B = TrapData.Behavior
	const M = TrapData.Mount
	_t({id = &"saw", display_name = "Sierra", description = "Corta y desmembra. Sangrado.", behavior = B.SAW, mount = M.FLOOR,
		cost = 40, damage = 5.0, cooldown = 0.18, trap_range = 13.0, elements = DamageInfo.CUT, dismember = 0.06, color = Color(0.85, 0.88, 0.92)})
	_t({id = &"flame", display_name = "Lanzallamas", description = "Columna de fuego. Incendia.", behavior = B.FLAME, mount = M.FLOOR,
		cost = 70, damage = 4.0, cooldown = 1.8, trap_range = 22.0, elements = DamageInfo.FIRE, color = Color(1.0, 0.55, 0.15)})
	_t({id = &"tesla", display_name = "Bobina Tesla", description = "Arco en cadena. Mojados: x2.", behavior = B.TESLA, mount = M.CEILING,
		cost = 90, damage = 12.0, cooldown = 1.1, trap_range = 70.0, elements = DamageInfo.ELECTRIC, chain_count = 3, color = Color(0.55, 0.85, 1.0)})
	_t({id = &"sprinkler", display_name = "Aspersor", description = "Moja y frena. Apaga el fuego.", behavior = B.SPRINKLER, mount = M.CEILING,
		cost = 35, damage = 0.0, cooldown = 0.3, trap_range = 30.0, elements = DamageInfo.WATER, color = Color(0.35, 0.65, 1.0)})
	_t({id = &"oil", display_name = "Aceite", description = "Charco pegajoso e inflamable.", behavior = B.OIL, mount = M.CEILING,
		cost = 45, damage = 0.0, cooldown = 5.0, trap_range = 26.0, elements = DamageInfo.OIL, color = Color(0.55, 0.45, 0.2)})
	_t({id = &"turret", display_name = "Torreta", description = "Dispara al más cercano del piso.", behavior = B.TURRET, mount = M.FLOOR,
		cost = 60, damage = 7.0, cooldown = 0.45, trap_range = 130.0, elements = DamageInfo.BLUNT, knockback = 40.0, color = Color(1.0, 0.9, 0.55)})
	_t({id = &"piston", display_name = "Pisón", description = "Aplasta y empuja hacia atrás.", behavior = B.PISTON, mount = M.CEILING,
		cost = 80, damage = 32.0, cooldown = 2.4, trap_range = 13.0, elements = DamageInfo.BLUNT, knockback = 160.0, dismember = 0.3, color = Color(0.75, 0.7, 0.65)})

static func _e(props: Dictionary) -> void:
	var e := EnemyData.new()
	for k in props:
		e.set(k, props[k])
	_enemies.append(e)

static func _build_enemies() -> void:
	_e({id = &"grunt", display_name = "Carroñero", hp = 34.0, speed = 22.0, cost = 1, min_wave = 1, bounty = 5,
		size = Vector2(10, 16)})
	_e({id = &"runner", display_name = "Corredor", hp = 16.0, speed = 44.0, cost = 1, min_wave = 2, bounty = 4,
		size = Vector2(8, 13), skin = Color(0.75, 0.55, 0.5), cloth = Color(0.2, 0.2, 0.28), eye = Color(1, 0.85, 0.2)})
	_e({id = &"bloater", display_name = "Hinchado", hp = 55.0, speed = 16.0, cost = 2, min_wave = 3, bounty = 8,
		size = Vector2(14, 15), skin = Color(0.6, 0.62, 0.35), cloth = Color(0.25, 0.25, 0.15), eye = Color(0.9, 1.0, 0.3),
		blood = Color(0.35, 0.3, 0.08), death_effect = EnemyData.DeathEffect.OIL_BURST, resist = {DamageInfo.FIRE: 1.5}})
	_e({id = &"brute", display_name = "Bruto", hp = 170.0, speed = 13.0, cost = 5, min_wave = 4, bounty = 22, lives_cost = 3,
		size = Vector2(16, 22), knockback_resist = 0.6, skin = Color(0.45, 0.48, 0.55), cloth = Color(0.35, 0.3, 0.3),
		eye = Color(1, 0.4, 0.0), resist = {DamageInfo.CUT: 0.5, DamageInfo.BLUNT: 0.8}})
