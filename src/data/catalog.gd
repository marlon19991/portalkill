class_name Catalog
extends RefCounted
## Catálogo central de contenido. Hoy se construye por código; cada entrada
## es un Resource y se puede guardar como .tres para editarla en el inspector.

static var _weapons: Dictionary = {}
static var _enemies: Array[EnemyData] = []

static func weapon(id: StringName) -> WeaponData:
	if _weapons.is_empty():
		_build_weapons()
	return _weapons[id]

static func weapon_ids() -> Array:
	if _weapons.is_empty():
		_build_weapons()
	return _weapons.keys()

static func enemies() -> Array[EnemyData]:
	if _enemies.is_empty():
		_build_enemies()
	return _enemies

static func _w(id: StringName, name: String, desc: String, behavior: WeaponData.Behavior, props: Dictionary) -> void:
	var w := WeaponData.new()
	w.id = id
	w.display_name = name
	w.description = desc
	w.behavior = behavior
	for k in props:
		w.set(k, props[k])
	_weapons[id] = w

static func _build_weapons() -> void:
	const B = WeaponData.Behavior
	_w(&"pistol", "Pistola", "Confiable. Ideal para infusiones.", B.PROJECTILE,
		{damage = 9.0, cooldown = 0.2, speed = 460.0, spread = 0.03, elements = DamageInfo.BLUNT,
		knockback = 70.0, recoil = 15.0, shake = 0.06, color = Color(1, 0.9, 0.55), length = 7.0})
	_w(&"machete", "Machete", "Corta extremidades. Sangrado.", B.MELEE,
		{damage = 18.0, cooldown = 0.32, weapon_range = 26.0, elements = DamageInfo.CUT,
		knockback = 120.0, dismember = 0.45, shake = 0.1, color = Color(0.85, 0.88, 0.92), length = 11.0})
	_w(&"shotgun", "Escopeta", "A quemarropa revienta todo.", B.PROJECTILE,
		{damage = 7.0, cooldown = 0.75, speed = 420.0, spread = 0.32, pellets = 7, elements = DamageInfo.BLUNT,
		knockback = 160.0, dismember = 0.22, recoil = 110.0, shake = 0.3, color = Color(1, 0.75, 0.4), length = 12.0})
	_w(&"molotov", "Molotov", "Incendia el suelo. Explota el aceite.", B.THROW,
		{damage = 6.0, cooldown = 0.7, speed = 300.0, gravity = 620.0, elements = DamageInfo.FIRE,
		knockback = 40.0, shake = 0.12, color = Color(1, 0.5, 0.1), length = 6.0})
	_w(&"taser", "Taser de arco", "Salta entre enemigos. Mojados: cadena x2.", B.CHAIN,
		{damage = 11.0, cooldown = 0.42, weapon_range = 150.0, chain_count = 3, elements = DamageInfo.ELECTRIC,
		knockback = 30.0, shake = 0.1, color = Color(0.55, 0.85, 1.0), length = 9.0})
	_w(&"hydro", "Hidrocañón", "Moja y empuja. Apaga fuego.", B.STREAM,
		{damage = 1.5, cooldown = 0.035, speed = 330.0, spread = 0.12, gravity = 380.0, elements = DamageInfo.WATER,
		knockback = 55.0, recoil = 4.0, shake = 0.0, color = Color(0.35, 0.65, 1.0), length = 10.0})

static func _e(props: Dictionary) -> void:
	var e := EnemyData.new()
	for k in props:
		e.set(k, props[k])
	_enemies.append(e)

static func _build_enemies() -> void:
	_e({id = &"grunt", display_name = "Carroñero", hp = 32.0, speed = 52.0, cost = 1, min_floor = 0,
		size = Vector2(10, 16), contact_damage = 10.0, jump_force = 300.0})
	_e({id = &"runner", display_name = "Corredor", hp = 16.0, speed = 105.0, accel = 900.0, jump_force = 320.0,
		cost = 1, min_floor = 0, size = Vector2(8, 13), contact_damage = 6.0,
		skin = Color(0.75, 0.55, 0.5), cloth = Color(0.2, 0.2, 0.28), eye = Color(1, 0.85, 0.2)})
	_e({id = &"brute", display_name = "Bruto", hp = 140.0, speed = 32.0, accel = 300.0, jump_force = 280.0,
		cost = 4, min_floor = 1, size = Vector2(16, 22), contact_damage = 22.0, knockback_resist = 0.75,
		skin = Color(0.45, 0.48, 0.55), cloth = Color(0.35, 0.3, 0.3), eye = Color(1, 0.4, 0.0),
		resist = {DamageInfo.CUT: 0.5, DamageInfo.BLUNT: 0.8}})
	_e({id = &"bloater", display_name = "Hinchado", hp = 45.0, speed = 38.0, accel = 400.0, jump_force = 275.0,
		cost = 2, min_floor = 1, size = Vector2(14, 15), contact_damage = 12.0,
		skin = Color(0.6, 0.62, 0.35), cloth = Color(0.25, 0.25, 0.15), eye = Color(0.9, 1.0, 0.3),
		blood = Color(0.35, 0.3, 0.08), death_effect = EnemyData.DeathEffect.OIL_BURST,
		resist = {DamageInfo.FIRE: 1.5}})
