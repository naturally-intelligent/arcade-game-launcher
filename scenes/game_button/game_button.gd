# GAME BUTTON
extends Button
class_name GameButton

var game_name: String 
var game: Game
var tween: Tween

var animated := false
var animation_tween: Tween

@onready var capsule: TextureRect = $Capsule
@onready var cross = $Cross

signal focused(button: Button)

func _ready() -> void:
	pivot_offset = size / 2.0
	
	cross.visible = false
	
	if game.get_file("capsule"):
		var tex: Texture = load_capsule_texture()
		if not tex: return
		capsule.texture = tex

func toggle_focus_visuals(state: bool) -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	if state:
		tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)
	else:
		tween.tween_property(self, "scale", Vector2.ONE, 0.4)

func _on_focus_entered() -> void:
	emit_signal("focused", self)
	toggle_focus_visuals(true)
	if animated:
		animation_tween.play()

func _on_mouse_entered() -> void:
	emit_signal("focused", self)
	toggle_focus_visuals(true)
	if animated:
		animation_tween.play()

func _on_focus_exited():
	toggle_focus_visuals(false)
	if animated:
		animation_tween.pause()

func _on_mouse_exited():
	toggle_focus_visuals(false)
	if animated:
		animation_tween.pause()

func _on_pressed():
	pass

func load_capsule_texture() -> Texture:
	if game.animated_capsule:
		var animated_capsule_path = game.get_file("animated_capsule")
		if animated_capsule_path:
			var animated_capsule_texture = _load_animated_capsule_texture(animated_capsule_path)
			if animated_capsule_texture:
				animated = true
				return animated_capsule_texture
	var static_capsule_path = game.get_file("capsule")
	return util.load_image_texture(static_capsule_path)

func _load_animated_capsule_texture(path: String) -> AnimatedAtlasTexture:
	var animated_capsule = AnimatedAtlasTexture.new()
	if !FileAccess.file_exists(path) || animated_capsule.load(path) != OK:
		return null
	else:
		var hframes = game.animated_capsule_hframes
		var vframes = game.animated_capsule_vframes
		animated_capsule.slice(hframes, vframes)

		var frame_count = game.animated_capsule_frame_count
		var frame_rate = game.animated_capsule_frame_rate
		animation_tween = animated_capsule.start_animation_tween(self, frame_count, frame_rate)
		animation_tween.pause()
		return animated_capsule
