class_name Weapon
extends RefCounted
## Instancia de un arma en el inventario: datos base + mejoras + infusiones.

var data: WeaponData
var damage_mult := 1.0
var rate_mult := 1.0
var extra_elements := 0
var level := 1
var _cd := 0.0

func _init(d: WeaponData) -> void:
	data = d

func elements() -> int:
	return data.elements | extra_elements

func damage() -> float:
	return data.damage * damage_mult

func display_name() -> String:
	var n := data.display_name
	if extra_elements & DamageInfo.FIRE: n += " ígnea"
	if extra_elements & DamageInfo.ELECTRIC: n += " voltaica"
	if extra_elements & DamageInfo.CUT: n += " dentada"
	if level > 1: n += " +%d" % (level - 1)
	return n

## Color principal: el de la infusión si tiene, si no el del arma.
func tint() -> Color:
	if extra_elements:
		return DamageInfo.element_color(extra_elements).lerp(data.color, 0.3)
	return data.color

func tick(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)

func ready_to_fire() -> bool:
	return _cd <= 0.0

## Dispara desde origin hacia dir. Devuelve el retroceso aplicado al jugador.
func fire(origin: Vector2, dir: Vector2) -> Vector2:
	if _cd > 0.0:
		return Vector2.ZERO
	_cd = data.cooldown / rate_mult
	var info := DamageInfo.make(damage(), elements(), dir, data.knockback, data.dismember)
	if extra_elements & DamageInfo.CUT:
		info.dismember += 0.2
	match data.behavior:
		WeaponData.Behavior.PROJECTILE:
			for i in data.pellets:
				var a := dir.angle() + Game.rng.randf_range(-data.spread, data.spread)
				var v := Vector2.from_angle(a) * data.speed * Game.rng.randf_range(0.9, 1.1)
				Game.projectiles.spawn(origin, v, ProjectileSystem.Kind.BULLET, info, tint(), 0.0, data.pierce, 0.9)
			Game.fx.muzzle(origin, dir, tint(), data.pellets > 1)
			Game.fx.shell(origin, dir)
		WeaponData.Behavior.STREAM:
			for i in 2:
				var a := dir.angle() + Game.rng.randf_range(-data.spread, data.spread)
				var v := Vector2.from_angle(a) * data.speed * Game.rng.randf_range(0.8, 1.15)
				Game.projectiles.spawn(origin, v, ProjectileSystem.Kind.WATER, info, tint().lightened(Game.rng.randf() * 0.3), data.gravity, 0, 0.9)
		WeaponData.Behavior.THROW:
			var v := (dir + Vector2(0, -0.35)).normalized() * data.speed
			Game.projectiles.spawn(origin, v, ProjectileSystem.Kind.MOLOTOV, info, tint(), data.gravity, 0, 3.0)
		WeaponData.Behavior.MELEE:
			Weapons.melee(origin, dir, data.weapon_range, info, tint())
		WeaponData.Behavior.CHAIN:
			Weapons.chain(origin, dir, data.weapon_range, data.chain_count, info, tint())
	if data.shake > 0.0:
		Events.screen_shake.emit(data.shake)
	return -dir * data.recoil
