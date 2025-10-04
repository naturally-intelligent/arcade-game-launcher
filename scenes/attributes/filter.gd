# FILTER BUTTON
@tool
extends Button
class_name Filter

@export var button_text: String : set = set_button_text
@export var icon_index: int : set = set_icon_index

func set_button_text(value: String):
	button_text = value
	text = value + '  '
	
func set_icon_index(value: int):
	icon_index = value
	$Icon/Sprite.frame = value

func _on_focus_entered():
	mark_focused()

func _on_focus_exited():
	mark_inactive()

func mark_active():
	modulate = Color.AQUA

func mark_inactive():
	modulate = Color("#aaaaaa")

func mark_focused():
	modulate = Color.YELLOW
