class_name SlotLayer
extends Node2D
## Marcas de casillas vacías (las "X" del boceto), selección y vista previa del alcance.

var traps: Dictionary
var selected := Vector2i(-1, -1)
var preview: TrapData
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	for f in Tower.FLOORS:
		for s in Tower.SLOT_X.size():
			var key := Vector2i(f, s)
			var x: float = Tower.SLOT_X[s]
			var gy := Tower.ground_y(f)
			if not traps.has(key):
				var a := 0.35 + 0.15 * sin(_t * 3.0 + f + s)
				var c := Color(1, 0.85, 0.4, a)
				for i in 5:
					draw_rect(Rect2(x - 3 + i, gy - 10 + i, 1, 1), c)
					draw_rect(Rect2(x + 1 - i, gy - 10 + i, 1, 1), c)
	if selected.x < 0:
		return
	var r := Tower.slot_rect(selected.x, selected.y)
	var pulse := 0.5 + 0.3 * sin(_t * 6.0)
	draw_rect(r, Color(1, 0.85, 0.4, 0.07))
	draw_rect(r, Color(1, 0.85, 0.4, pulse), false, 1.0)
	var td: TrapData = preview
	if traps.has(selected):
		td = (traps[selected] as Trap).data
	if td:
		var reach := td.trap_range
		if traps.has(selected):
			reach = (traps[selected] as Trap).reach()
		var gy := Tower.ground_y(selected.x)
		var x: float = Tower.SLOT_X[selected.y]
		draw_rect(Rect2(x - reach, gy - 2, reach * 2.0, 2), Color(td.color, 0.5))
