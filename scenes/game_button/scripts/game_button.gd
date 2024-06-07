# GAME BUTTON
extends Button
class_name GameButton

signal focused(who: Button)

var game_name: String 
var properties: Game
var tween: Tween

@onready var capsule: TextureRect = $Capsule
@onready var cross = $Cross

func _ready() -> void:
	pivot_offset = size / 2.0
	
	cross.visible = false
	
	if properties.file("capsule"):
		var tex: Texture = load_capsule_texture()
		if not tex: return
		capsule.texture = tex

func load_capsule_texture() -> Texture:
	var animated_capsule_path = properties.file("animated_capsule")
	var animated_capsule_texture = _load_animated_capsule_texture(animated_capsule_path)
	if animated_capsule_texture:
		return animated_capsule_texture
	else:
		var static_capsule_path = properties.file("capsule")
		return FileUtilities.load_image_texture(static_capsule_path)

func _load_animated_capsule_texture(path: String) -> AnimatedAtlasTexture:
	var animated_capsule = AnimatedAtlasTexture.new()
	if animated_capsule.load(path) != OK:
		return null
	else:
		var hframes = properties.animated_capsule_hframes
		var vframes = properties.animated_capsule_vframes
		animated_capsule.slice(hframes, vframes)

		var frame_count = properties.animated_capsule_frame_count
		var frame_rate = properties.animated_capsule_frame_rate
		animated_capsule.start_animation_tween(self, frame_count, frame_rate)
		return animated_capsule

func load_image_texture(path: String) -> ImageTexture:
	var capsule_im: Image = Image.new()
	if capsule_im.load(path) != OK:
		print("BAD STUFF, CANT LOAD CAPSULE AT: ", properties.file("capsule"))
		return null
	else:
		var tex: ImageTexture = ImageTexture.new()
		tex.set_image(capsule_im)
		return tex

func toggle_focus_visuals(state: bool) -> void:
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	if state:
		tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.2)
		#tween.tween_property(self, "rotation_degrees", 360.0, 0.2).from(0.0)
	else:
		tween.tween_property(self, "scale", Vector2.ONE, 0.4)
		#tween.tween_property(self, "rotation_degrees", -360.0, 0.3).from(0.0)

func _on_focus_entered() -> void:
	focused.emit(self)
	toggle_focus_visuals(true)

func _on_mouse_entered() -> void:
	focused.emit(self)
	toggle_focus_visuals(true)

func _on_focus_exited():
	toggle_focus_visuals(false)

func _on_mouse_exited():
	toggle_focus_visuals(false)

func _on_pressed():
	pass
