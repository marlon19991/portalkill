class_name GlowLayer
extends Node2D
## Capa con mezcla aditiva. El dueño dibuja aquí sus brillos mediante un Callable.
## Un único material aditivo compartido → los brillos se agrupan en pocos draw calls.

static var _mat: CanvasItemMaterial
var painter: Callable

func _init(p: Callable) -> void:
	painter = p
	if _mat == null:
		_mat = CanvasItemMaterial.new()
		_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _mat

func _draw() -> void:
	painter.call(self)
