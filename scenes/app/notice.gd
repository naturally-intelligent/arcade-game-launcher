extends Label
class_name Notice

func _on_fade_timer():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 2)

func _on_expire_timer():
	queue_free()
