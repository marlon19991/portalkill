class_name Elements
extends RefCounted
## Reglas de interacción elemental. Para agregar un combo nuevo, agrega una regla aquí.
## Las armas solo producen DamageInfo; este módulo decide estados y reacciones.

const BURN_TIME := 3.5
const WET_TIME := 6.0
const OIL_TIME := 12.0
const BLEED_TIME := 4.0

static func apply_hit(e: Enemy, info: DamageInfo) -> void:
	if e.dead:
		return
	var amount := info.amount
	for bit in e.data.resist:
		if info.elements & int(bit):
			amount *= float(e.data.resist[bit])

	# --- Agua: moja y apaga.
	if info.has(DamageInfo.WATER):
		if e.burning > 0.0:
			e.burning = 0.0
			Game.fx.steam(e.center())
			_react("VAPOR", e.center(), Color(0.8, 0.9, 1.0))
		e.wet = WET_TIME

	# --- Aceite: impregna.
	if info.has(DamageInfo.OIL):
		e.oiled = OIL_TIME

	# --- Fuego: apaga si mojado, explota si aceite, si no incendia.
	if info.has(DamageInfo.FIRE):
		if e.wet > 0.0:
			e.wet = maxf(0.0, e.wet - 3.0)
			Game.fx.steam(e.center())
		elif e.oiled > 0.0:
			e.oiled = 0.0
			e.burning = BURN_TIME * 2.0
			_react("¡IGNICIÓN!", e.center(), Color(1, 0.6, 0.1))
			explode(e.center(), 44.0, 26.0, DamageInfo.FIRE)
		else:
			e.burning = maxf(e.burning, BURN_TIME)

	# --- Electricidad: aturde; mojado = daño y aturdimiento extra.
	if info.has(DamageInfo.ELECTRIC):
		var stun := 0.45
		if e.wet > 0.0:
			stun = 1.3
			amount *= 1.6
			Game.fx.sparks(e.center(), 10, Color(0.6, 0.9, 1.0))
		e.stun = maxf(e.stun, stun)
		e.shock_fx = 0.3

	# --- Corte: sangrado y desmembramiento.
	if info.has(DamageInfo.CUT):
		e.bleeding = BLEED_TIME

	e.take_damage(amount, info)

## Daño en área. Aplica elementos a enemigos y, opcionalmente, al jugador.
static func explode(pos: Vector2, radius: float, damage: float, elements: int) -> void:
	Game.fx.explosion(pos, radius)
	Events.screen_shake.emit(clampf(radius / 80.0, 0.25, 0.7))
	Events.hitstop.emit(0.05)
	if elements & DamageInfo.FIRE:
		Game.fx.add_fire_zone(pos, radius * 1.2, 4.0)
	for e: Enemy in Game.enemies.duplicate():
		if not e.targetable():
			continue
		var d := e.center().distance_to(pos)
		if d < radius:
			var k := 1.0 - d / radius * 0.6
			var info := DamageInfo.make(damage * k, elements | DamageInfo.BLUNT, (e.center() - pos).normalized(), 260.0 * k, 0.5)
			apply_hit(e, info)

static func _react(text: String, pos: Vector2, color: Color) -> void:
	Game.fx.float_text(text, pos + Vector2(0, -14), color)
	Events.reaction.emit(text, pos)

## Arco eléctrico que salta entre enemigos cercanos del mismo piso. Los mojados extienden la cadena.
static func chain_from(start: Enemy, jumps: int, amount: float, radius: float, color: Color = Color(0.6, 0.9, 1.0)) -> void:
	var visited: Array = [start]
	var cur := start
	var dmg := amount
	while jumps > 0 and cur:
		var nxt: Enemy = null
		var nd := INF
		var r := radius * (1.5 if cur.wet > 0.0 else 1.0)
		for e in Game.enemies:
			if not e.targetable() or e.floor_i != cur.floor_i or visited.has(e):
				continue
			var d := e.center().distance_to(cur.center())
			if d < r and d < nd:
				nd = d
				nxt = e
		if nxt == null:
			break
		Game.fx.lightning(cur.center(), nxt.center(), color)
		visited.append(nxt)
		if nxt.wet > 0.0:
			jumps += 1
		apply_hit(nxt, DamageInfo.make(dmg, DamageInfo.ELECTRIC, (nxt.center() - cur.center()).normalized(), 20.0))
		dmg *= 0.9
		cur = nxt
		jumps -= 1
