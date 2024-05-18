extends Label
class_name Notice

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_fade_timer():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 2)

func _on_expire_timer():
	queue_free()
