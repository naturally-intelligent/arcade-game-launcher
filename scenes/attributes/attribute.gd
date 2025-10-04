# ATTRIBUTE
@tool
extends HBoxContainer
class_name Attribute

@export var text: String : set = set_text
@export var icon: int : set = set_icon

func set_text(_text: String):
	text = _text
	$Label.text = _text
	
func set_icon(_icon: int):
	icon = _icon
	$Icon/Sprite.frame = _icon
