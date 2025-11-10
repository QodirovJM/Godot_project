extends TextureButton
class_name AttackButton

signal attack_pressed

func _ready() -> void:
	# Делаем кнопку видимой только на мобильных
	visible = OS.has_feature("mobile") or OS.has_feature("web")
	
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	attack_pressed.emit()
	# Можно добавить визуальный эффект нажатия
	modulate = Color(1, 1, 1, 0.5)
	await get_tree().create_timer(0.1).timeout
	modulate = Color.WHITE
