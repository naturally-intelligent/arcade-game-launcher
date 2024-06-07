class_name AnimatedAtlasTexture
extends AtlasTexture

@export var horizontal_frame_count: int = 1
@export var vertical_frame_count: int = 1
@export var frame_size: Vector2i = Vector2i(600, 900)


func load(path: String) -> int:
	var source_texture = FileUtilities.load_image_texture(path)
	if source_texture:
		atlas = source_texture
		return OK
	return ERR_CANT_OPEN

func slice(horizontal_frames: int = 1, vertical_frames: int = 1):
	horizontal_frame_count = horizontal_frames
	vertical_frame_count = vertical_frames

	var atlas_size: Vector2i = atlas.get_size()
	frame_size = atlas_size
	frame_size.x /= horizontal_frame_count
	frame_size.y /= vertical_frame_count

	region = Rect2i(0, 0, frame_size.x, frame_size.y)

func start_animation_tween(bound_node: Node, frame_count: int = 1, frame_rate: int = 12):
	if frame_count == 1:
		if horizontal_frame_count == 1 && vertical_frame_count == 1:
			return
		frame_count = horizontal_frame_count * vertical_frame_count
		
	var duration = float(frame_count) / frame_rate
	var animation_tween = bound_node.create_tween()
	animation_tween.set_loops()
	animation_tween.set_trans(Tween.TRANS_LINEAR)
	animation_tween.tween_method(_set_animation_frame, -0.999, frame_count - 1, duration)


func _set_animation_frame(frame_value: float):
	var frame_index: int = ceil(frame_value)
	var frame_offset = Vector2i()
	frame_offset.x = frame_index % horizontal_frame_count
	frame_offset.y = frame_index / horizontal_frame_count

	region.position = Vector2(frame_offset * frame_size)
