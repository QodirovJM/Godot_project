extends Control

signal moved(vec: Vector2)   # нормализованный [-1..1]

@export var radius: float = 80.0

var _dragging: bool = false
var _vec: Vector2 = Vector2.ZERO
var _center_pos: Vector2 = Vector2.ZERO

@onready var bg: TextureRect = $Background
@onready var stick: TextureRect = $Stick

func _ready() -> void:
	# Центр стика в пределах контейнера
	_center_pos = (size / 2.0) - (stick.size / 2.0)
	stick.position = _center_pos

func _gui_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		_dragging = e.pressed
		if not _dragging:
			_reset()

	elif e is InputEventScreenDrag and _dragging:
		# Позиция касания в локальных координатах контрола
		var local: Vector2 = e.position - global_position
		var from_center: Vector2 = local - (size / 2.0)
		# Ограничиваем длину вектора радиусом
		_vec = from_center.limit_length(radius) / radius
		stick.position = _center_pos + _vec * radius
		emit_signal("moved", _vec)

func _reset() -> void:
	_vec = Vector2.ZERO
	stick.position = _center_pos
	emit_signal("moved", _vec)

func get_vector() -> Vector2:
	return _vec
