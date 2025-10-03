extends Control
class_name GamesCarousel

@export var button_offset: Vector2

var tween: Tween

var selected_idx := 0
var can_move: bool = true

# Filtering
var all_games: Dictionary = {}
var filtered_games: Dictionary = {}
var active_filter: String = ""

func _ready():
	pass # Replace with function body.

func _input(event: InputEvent):
	# Only handle input if we're not in tag filter mode
	if not get_parent().tag_filter_focused:
		if event.is_action_pressed("ui_left"): 
			if can_move:
				move_left()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			if can_move:
				move_right()
			get_viewport().set_input_as_handled()
	
func create_game_buttons(game_button: PackedScene, to_create: Dictionary) -> Array:
	# Store all games for filtering
	all_games = to_create.duplicate(true)
	filtered_games = to_create.duplicate(true)
	
	return refresh_game_buttons(game_button)

func refresh_game_buttons(game_button: PackedScene) -> Array:
	# Clear existing buttons immediately
	var children = get_children()
	for child in children:
		remove_child(child)
		child.queue_free()
	
	print("DEBUG: Creating ", filtered_games.size(), " game buttons from filtered games")
	
	var count: int = 0
	for key in filtered_games.keys():
		var game: Game = filtered_games[key]
		if game.visible:
			var instance: GameButton = game_button.instantiate()
			instance.game_name = game.subdirectory
			instance.properties = game
			add_child(instance)
			instance.position -= instance.size / 2.0
			instance.position.x += (instance.size.x + button_offset.x) * count
			count += 1
			print("DEBUG: Created button for game: ", game.title)
	
	# Reset selection to first item
	selected_idx = 0
	
	print("DEBUG: Total children after refresh: ", get_child_count())
	
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

# Filtering methods
func filter_by_tag(tag: String, game_button: PackedScene) -> void:
	print("DEBUG: Filtering by tag: ", tag)
	if tag == "":
		# Show all games
		filtered_games = all_games.duplicate(true)
		active_filter = ""
		print("DEBUG: Showing all games, count: ", filtered_games.size())
	else:
		# Filter games by tag
		filtered_games.clear()
		for key in all_games.keys():
			var game: Game = all_games[key]
			print("DEBUG: Checking game ", game.title, " with tags: ", game.tags)
			if tag in game.tags:
				print("DEBUG: Adding game ", game.title, " to filtered list")
				filtered_games[key] = game
		active_filter = tag
		print("DEBUG: Filtered games count: ", filtered_games.size())
	
	# Refresh the UI with filtered games
	refresh_game_buttons(game_button)

func get_all_tags() -> Array[String]:
	var tag_set: Array[String] = []
	for key in all_games.keys():
		var game: Game = all_games[key]
		for tag in game.tags:
			if tag not in tag_set:
				tag_set.append(tag)
	tag_set.sort()
	return tag_set

func get_all_attributes() -> Array[String]:
	var attribute_set: Array[String] = []
	for key in all_games.keys():
		var game: Game = all_games[key]
		for attribute in game.attributes.keys():
			if game.attributes[attribute] == true and attribute not in attribute_set:
				attribute_set.append(attribute)
	attribute_set.sort()
	return attribute_set

func get_active_filter() -> String:
	return active_filter

# Attribute-based filtering
func filter_by_attribute(attribute: String, game_button: PackedScene) -> void:
	print("DEBUG: Filtering by attribute: ", attribute)
	filtered_games.clear()
	
	for key in all_games.keys():
		var game: Game = all_games[key]
		print("DEBUG: Checking game ", game.title, " for attribute ", attribute, ": ", game.attributes.get(attribute, false))
		if game.attributes.get(attribute, false) == true:
			print("DEBUG: Adding game ", game.title, " to filtered list")
			filtered_games[key] = game
	
	print("DEBUG: Filtered games count: ", filtered_games.size())
	active_filter = attribute.capitalize()
	refresh_game_buttons(game_button)

# Date-based sorting (no threshold)
func filter_by_recent_date(game_button: PackedScene, _days: int = 30) -> void:
	# Sort all games by date_added (most recent first), games without dates go to back
	var games_with_dates: Array = []
	var games_without_dates: Array = []
	
	# Separate games with and without dates
	for key in all_games.keys():
		var game: Game = all_games[key]
		if game.date_added != "":
			games_with_dates.append({"key": key, "game": game, "date": game.date_added})
		else:
			games_without_dates.append({"key": key, "game": game})
	
	# Sort games with dates by date (most recent first)
	games_with_dates.sort_custom(func(a, b): return is_date_after(a.date, b.date))
	
	# Rebuild filtered_games with sorted order
	filtered_games.clear()
	
	# Add games with dates first (sorted by most recent)
	for item in games_with_dates:
		filtered_games[item.key] = item.game
	
	# Add games without dates at the end
	for item in games_without_dates:
		filtered_games[item.key] = item.game
	
	print("DEBUG: Sorted ", games_with_dates.size(), " games with dates, ", games_without_dates.size(), " without dates")
	active_filter = "Recently Added"
	refresh_game_buttons(game_button)

func get_date_days_ago(days: int) -> String:
	var current_date = Time.get_datetime_dict_from_system()
	var past_date = current_date.duplicate()
	
	# Subtract days
	past_date.day -= days
	
	# Handle month/year rollover
	while past_date.day <= 0:
		past_date.month -= 1
		if past_date.month <= 0:
			past_date.month = 12
			past_date.year -= 1
		
		# Get days in the previous month
		var days_in_month = get_days_in_month(past_date.month, past_date.year)
		past_date.day += days_in_month
	
	# Format as DD-MM-YYYY
	return "%02d-%02d-%04d" % [past_date.day, past_date.month, past_date.year]

func get_days_in_month(month: int, year: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12: return 31
		4, 6, 9, 11: return 30
		2: return 29 if is_leap_year(year) else 28
		_: return 30

func is_leap_year(year: int) -> bool:
	return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0)

func is_date_after(date_str: String, cutoff_str: String) -> bool:
	# Parse DD-MM-YYYY format
	var date_parts = date_str.split("-")
	var cutoff_parts = cutoff_str.split("-")
	
	if date_parts.size() != 3 or cutoff_parts.size() != 3:
		return false
	
	var date_day = int(date_parts[0])
	var date_month = int(date_parts[1])
	var date_year = int(date_parts[2])
	
	var cutoff_day = int(cutoff_parts[0])
	var cutoff_month = int(cutoff_parts[1])
	var cutoff_year = int(cutoff_parts[2])
	
	# Compare dates
	if date_year > cutoff_year:
		return true
	elif date_year < cutoff_year:
		return false
	elif date_month > cutoff_month:
		return true
	elif date_month < cutoff_month:
		return false
	else:
		return date_day >= cutoff_day
