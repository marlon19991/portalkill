class_name Weapons
extends RefCounted
## Comportamientos de armas que no son proyectiles (cuerpo a cuerpo, cadenas).

static func melee(origin: Vector2, dir: Vector2, reach: float, info: DamageInfo, color: Color) -> void:
	Game.fx.slash(origin, dir, reach, color)
	var hit_any := false
	for e: Enemy in Game.enemies.duplicate():
		if e.dead or e.spawning > 0.0:
			continue
		var to := e.center() - origin
		var d := to.length()
		if d < reach + e.data.size.x * 0.5 and (d < 6.0 or absf(dir.angle_to(to)) < 1.25):
			var hi := info.copy()
			hi.dir = (to.normalized() + Vector2(0, -0.3)).normalized()
			Elements.apply_hit(e, hi)
			Game.blood.spray(e.center(), hi.dir, 14, e.data.blood)
			hit_any = true
	if hit_any:
		Events.hitstop.emit(0.035)
		Events.screen_shake.emit(0.12)

## Arco eléctrico: busca objetivo en el cono de mira y salta en cadena.
static func chain(origin: Vector2, dir: Vector2, reach: float, jumps: int, info: DamageInfo, color: Color) -> void:
	var best: Enemy = null
	var best_score := INF
	for e in Game.enemies:
		if e.dead or e.spawning > 0.0:
			continue
		var to := e.center() - origin
		var d := to.length()
		if d > reach:
			continue
		var ang := absf(dir.angle_to(to))
		if ang > 0.9 and d > 30.0:
			continue
		var score := d + ang * 60.0
		if score < best_score:
			best_score = score
			best = e
	if best == null:
		# chispazo al aire
		Game.fx.lightning(origin, origin + dir * reach * 0.45, color)
		return
	Game.fx.lightning(origin, best.center(), color)
	var bonus := 2 if best.wet > 0.0 else 0
	var hi := info.copy()
	hi.dir = dir
	Elements.apply_hit(best, hi)
	chain_from(best, jumps - 1 + bonus, info.amount * 0.85, 70.0, color)

static func chain_from(start: Enemy, jumps: int, amount: float, radius: float, color: Color = Color(0.6, 0.9, 1.0)) -> void:
	var visited: Array = [start]
	var cur := start
	var dmg := amount
	while jumps > 0 and cur:
		var nxt: Enemy = null
		var nd := INF
		var r := radius * (1.5 if cur.wet > 0.0 else 1.0)
		for e in Game.enemies:
			if e.dead or visited.has(e):
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
		Elements.apply_hit(nxt, DamageInfo.make(dmg, DamageInfo.ELECTRIC, (nxt.center() - cur.center()).normalized(), 30.0))
		dmg *= 0.9
		cur = nxt
		jumps -= 1
