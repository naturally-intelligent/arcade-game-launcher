# CAROUSEL
extends Control
class_name GamesCarousel

@export var launcher: ArcadeLauncher
@export var button_offset: Vector2

var tween: Tween
var selected_idx := 0
var can_move: bool = true
var randomize := true

# Filtering
var all_games: Dictionary = {}
var filtered_games: Dictionary = {}
var active_filter: String = ""

func _ready():
	pass

func _input(event: InputEvent):
	# Only handle input if we're not in tag filter mode
	if not launcher.filter_focused:
		if Input.is_action_pressed("ui_left"): 
			if can_move:
				move_left()
			get_viewport().set_input_as_handled()
		elif Input.is_action_pressed("ui_right"):
			if can_move:
				move_right()
			get_viewport().set_input_as_handled()
	
func create_game_buttons(game_button: PackedScene, to_create: Dictionary) -> Array:
	# Store all games for filtering
	all_games = to_create.duplicate(true)
	filtered_games = to_create.duplicate(true)
	
	return refresh_game_buttons(game_button)

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

func get_all_attributes() -> Array[String]:
	var attribute_set: Array[String] = []
	for key: String in all_games.keys():
		var game: Game = all_games[key]
		for attribute: String in game.attributes.keys():
			var value := bool(game.attributes[attribute])
			if value == true and attribute not in attribute_set:
				attribute_set.append(attribute)
	attribute_set.sort()
	return attribute_set

# WARNING: AI-generated code below

func refresh_game_buttons(game_button_tscn: PackedScene, allow_random := true) -> Array:
	# Clear existing buttons immediately
	var children = get_children()
	for child in children:
		remove_child(child)
		child.queue_free()
	
	#print("DEBUG: Creating ", filtered_games.size(), " game buttons from filtered games")
	
	var game_buttons := []
	for key in filtered_games.keys():
		var game: Game = filtered_games[key]
		if game.visible:
			var game_button: GameButton = game_button_tscn.instantiate()
			game_button.launcher = launcher
			game_button.game_name = game.subdirectory
			game_button.game = game
			game_buttons.append(game_button)
			#print("DEBUG: Created button for game: ", game.title)
	
	if randomize and allow_random:
		game_buttons.shuffle()
	var count: int = 0
	for game_button in game_buttons:
		game_button.position -= game_button.size / 2.0
		game_button.position.x += (game_button.size.x + button_offset.x) * count
		add_child(game_button)
		count += 1
	
	# Reset selection to first item
	selected_idx = 0
	
	#print("DEBUG: Total children after refresh: ", get_child_count())
	
	if get_child_count() > 0: 
		# Call deferred to make sure the app has time to connect focus signal and react accordingly
		get_child(0).call_deferred("grab_focus")
		
	return get_children() 

func get_active_filter() -> String:
	return active_filter

# Attribute-based filtering
func filter_by_attribute(attribute: String, game_button: PackedScene) -> void:
	#print("DEBUG: Filtering by attribute: ", attribute)
	filtered_games.clear()
	
	for key in all_games.keys():
		var game: Game = all_games[key]
		#print("DEBUG: Checking game ", game.title, " for attribute ", attribute, ": ", game.attributes.get(attribute, false))
		var value := bool(game.attributes.get(attribute, false))
		if value == true or not attribute:
			#print("DEBUG: Adding game ", game.title, " to filtered list")
			filtered_games[key] = game
	
	#print("DEBUG: Filtered games count: ", filtered_games.size())
	active_filter = attribute
	refresh_game_buttons(game_button)

# Date-based sorting (no threshold)
func filter_by_recent_date(game_button: PackedScene, recent_max := 3, _days: int = 30) -> void:
	# Sort all games by date_added (most recent first), games without dates go to back
	var games_with_dates: Array = []
	
	# Separate games with and without dates
	for key in all_games.keys():
		var game: Game = all_games[key]
		print(game.title, game.date_added)
		if game.date_added != "":
			games_with_dates.append({"key": key, "game": game, "date": game.date_added})
	
	# Sort games with dates by date (most recent first)
	games_with_dates.sort_custom(func(a, b): return util.is_date_after(a.date, b.date))
	
	if games_with_dates.is_empty():
		return
	
	# Rebuild filtered_games with sorted order
	filtered_games.clear()
	
	# Add games with dates first (sorted by most recent)
	var count := 0
	for item in games_with_dates:
		count += 1
		if count <= recent_max:
			filtered_games[item.key] = item.game
	
	#print("DEBUG: Sorted ", games_with_dates.size(), " games with dates, ", games_without_dates.size(), " without dates")
	active_filter = "recent"
	refresh_game_buttons(game_button, false)
