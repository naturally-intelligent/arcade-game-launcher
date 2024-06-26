extends Control
class_name GamesCarousel

@export var button_offset: Vector2

var tween: Tween

var selected_idx := 0
var can_move: bool = true

func _ready():
	pass # Replace with function body.

func _input(event: InputEvent):
	if event.is_action_pressed("ui_left"): 
		if can_move:
			move_left()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		if can_move:
			move_right()
		get_viewport().set_input_as_handled()
	
func create_game_buttons(game_button: PackedScene, to_create: Dictionary) -> Array:
	var count: int = 0
	for key in to_create.keys():
		var game: Game = to_create[key]
		if game.visible:
			var instance: GameButton = game_button.instantiate()
			instance.game_name = game.subdirectory
			instance.properties = game
			add_child(instance)
			instance.position -= instance.size / 2.0
			instance.position.x += (instance.size.x + button_offset.x) * count
			count += 1
	
	if get_child_count() > 0: 
		# Call deferred to make sure the app has time to connect focus signal and react accordingly
		get_child(0).call_deferred("grab_focus")
		
	return get_children() 

func scroll_left() -> bool:
	if can_move:
		return move_left()
	focus_selected()
	return false

func scroll_right() -> bool:
	if can_move:
		return move_right()
	focus_selected()
	return false

func focus_selected() -> void:
	var child = get_child(selected_idx)
	if child: 
		child.grab_focus()
	else:
		print("WARNING: could not find carousel child ", selected_idx)

func move_left() -> bool:
	if selected_idx == 0: 
		return false
	
	var next_idx: int = selected_idx - 1
	
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	# Get the currently selected button id
	for i in range(get_child_count()):
		var c: Button = get_child(i)
		var diff: int = next_idx - i
		tween.tween_property(c, "position:x", -(c.size.x/2.0) - ((c.size.x + button_offset.x) * diff), 0.3)
	
	# Select the next button
	selected_idx = next_idx
	focus_selected()
	return true

func move_right() -> bool:
	if selected_idx == get_child_count() - 1: 
		return false
	
	var next_idx: int = selected_idx + 1
	
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC).set_parallel(true)
	
	for i in range(get_child_count()):
		var c: Button = get_child(i)
		var diff: int = i - next_idx
		# -(c.size.x/2.0) is to offset the button to be in the center, otherwise it's positionned
		# with the top left corner
		tween.tween_property(c, "position:x", -(c.size.x/2.0) + ((c.size.x + button_offset.x) * diff), 0.3)

	# Select the next button
	selected_idx = next_idx 
	focus_selected()
	return true
