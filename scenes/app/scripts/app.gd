# APP
extends Control

@export var game_button: PackedScene
@export var default_bg: Texture
@export_enum("windows", "linux") var platform := "windows"
@export var enforce_platform := false
@export var verbose := true
@export var autoscan := true
@export var verbose_console := true
@export var autoscroll := false
@export var show_version := true
@export var screensaver := false
@export var allow_mouse := false

var pid_watching: int = -1
var games: Dictionary
var current_game: Game
var allow_game_launch := false

# Navigation state
var tag_filter_focused: bool = false
var current_tag_index: int = 0

const console_spam_max = 3
var console_spam := 0

var autoscroll_direction := 1
var screensaver_tween: Tween

@onready var bg: TextureRect = $BG
@onready var pid_timer: Timer = $Timers/PIDTimer
@onready var games_container: GamesCarousel = $Games
@onready var no_game_found = $NoGameFound
@onready var title: Label = $Description/Title
@onready var description: Label = $Description/Description
@onready var version_btn = $VersionBtn

@onready var check_for_updates := false
@onready var update_checker := UpdateChecker.new()

@onready var tag_container: HBoxContainer

var launcher_config: ConfigFile
var launcher_config_file := "launcher.ini"

var log_file := "arcadelog.txt"
var time_start: float
var time_end: float

const notice_tscn = preload("res://scenes/notice/notice.tscn")

func _ready() -> void:
	# LAUNCHER CONFIG (optional)
	load_launcher_config()
	
	# UPDATES
	if check_for_updates:
		add_child(update_checker)
		update_checker.get_latest_version()
		update_checker.release_parsed.connect(on_released_parsed)
	$VersionBtn.visible = show_version
	
	# SETUP
	configure_pid_timer()
	var base_dir: String = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	create_game_folder(base_dir)
	manually_add_games(base_dir.path_join("games"))
	if autoscan:
		scan_for_games(base_dir.path_join("games"))
	setup_overlay()
	start_allow_launch_timer()
	hide_attributes()
	
	# PRINT
	print_games_to_console()
	
	# WARNINGS
	if games.is_empty():
		no_game_found.visible = true
	
	# UI
	var buttons: Array = games_container.create_game_buttons(game_button, games)
	for b: GameButton in buttons:
		b.focused.connect(on_game_btn_focused)
		b.pressed.connect(on_game_btn_pressed.bind(b))
	
	# Setup tag filtering
	setup_tag_filters()
	
	# AUTOMATION (screensaver, autoscroll)
	screensaver_setup()
	autoscroll_setup()
	reset_automation()
	hide_load_screen()

	print("Log File: " + log_file + " in: " + OS.get_user_data_dir())

	# MOUSE
	if not allow_mouse:
		# hide mouse, and lock to middle of screen
		# can still be clicked but works well here because our focus game is in middle!
		# to fully disable mouse clicks we could change all the buttons input modes (meh)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	# Test
	#launch_game("Dashpong")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("About to quit, killing process")
		_write_log("QUIT")
		stop_game(pid_watching)
		
		# Maybe use a softer method, by sending a WM_CLOSE message first
		# windows only
		# NOT TESTED YET
		#taskkill /PID pid_watching
		#OS.execute(taskkill, ("/PID", str(pid_watching)])

func _input(event):
	if Input.is_action_just_pressed("toggle_fullscreen"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if event.is_action_pressed("kill"):
		stop_game(pid_watching)
	if screensaver:
		stop_screensaver()
	if autoscroll:
		stop_autoscrolling()
	
	# Handle tag navigation
	handle_tag_navigation(event)

func configure_pid_timer() -> void:
	# Configure the timer
	pid_timer.one_shot = false
	pid_timer.wait_time = 1.0
	pid_timer.timeout.connect(on_pid_timer_timeout)

func create_game_folder(base_dir: String) -> void:
	var dir = DirAccess.open(base_dir)
	if dir.dir_exists(base_dir.path_join("games")): return
	dir.make_dir(base_dir.path_join("games"))

func scan_for_games(path: String) -> void:
	var dir := DirAccess.open(path)
	
	dir.include_hidden = false
	dir.include_navigational = false
	
	if not dir: 
		print("An error occurred when trying to access the path.")
		return
		
	# directory loop
	dir.list_dir_begin()
	var game_dir := dir.get_next()
	while game_dir != "":
		# We found a game, explore its content
		if dir.current_is_dir():
			print("GAME detected in subdirectory scan: ", game_dir)
			var subdir_path: String = path.path_join(game_dir)
			add_game_from_directory(subdir_path, game_dir)
			
		game_dir = dir.get_next()
	
func manually_add_games(_path: String) -> void:
	if launcher_config.has_section("GAMES"):
		for key in launcher_config.get_section_keys("GAMES"):
			var game_data = launcher_config.get_value("GAMES", key)
			if typeof(game_data) == TYPE_STRING:
				var game_dir = key
				var subdir_path = game_data
				print("GAME detected in config: ", game_dir)
				add_game_from_directory(subdir_path, game_dir)	
			elif typeof(game_data) == TYPE_ARRAY and game_data.size() == 2:
				var game_dir = game_data[0]
				var subdir_path = game_data[1]
				print("GAME detected in config array: ", game_dir)
				add_game_from_directory(subdir_path, game_dir)
	
func add_game_from_directory(subdir_path: String, game_dir: String) -> void:
	print("- add_game_from_directory: ", subdir_path)
	var subdir := DirAccess.open(subdir_path)
	var game := Game.new()
	game.subdirectory = game_dir
	game.subdirectory_path = subdir.get_current_dir()
	subdir.list_dir_begin()
	var file = subdir.get_next()
	while file != "":
		if not subdir.current_is_dir():
			var extension: String = file.get_extension().to_lower()
			var check_dir: String = subdir.get_current_dir()
			var check_file: String = subdir.get_current_dir().path_join(file)
			var basename: String = file.get_basename()
			match extension:
				"exe":
					if platform == "windows" or not enforce_platform:
						print("Executable: ", check_dir)
						game.executable = file
						game.platform = 'windows'
				"x86_64", "sh":
					if platform == "linux" or not enforce_platform:
						print("Executable: ", check_dir)
						game.executable = file
						game.platform = 'linux'
				"dmg":
					#TODO: make functional with mac (add osx to platforms enum at top)
					if platform == "osx" or not enforce_platform:
						print("OSX Executable: Not supported")
						game.platform = 'osx'
				"jpg", "jpeg", "png":
					if basename == "capsule":
						game.capsule = file
					elif basename == "bg":
						game.background = file
				"txt":
					if basename == "description":
						var text_file = FileAccess.open(check_file, FileAccess.READ)
						var content = text_file.get_as_text(true)
						game.description = content
				"ini", "cfg":
					if basename == "config":
						var config = ConfigFile.new()
						var status = config.load(check_file)
						if status == OK:
							game.config = config
						else:
							print("WARNING: bad config file ", status)

		file = subdir.get_next() # while
	# check config for overrides (must be done last)
	game.parse_config()
	if game.available:
		games[game_dir] = game
	
func print_games_to_console() -> void:
	print("\nGAMES:\n")
	for key in games:
		var game: Game = games[key]
		print(key, ": ", game.debug_line())

# LAUNCH 
	
func launch_game(game_name: String) -> bool:
	var game: Game = games[game_name]
	console_spam = 0
	add_notice("Launching game: " + game.title, verbose)
	log_game_start(game)
	if not game.executable: 
		add_notice("No executable set for game: " + game.title)
		return false
	var executable_path: String = game.file("executable")
	if FileAccess.file_exists(executable_path):
		games_container.can_move = false
		pid_watching = OS.create_process(executable_path, game.arguments)
		pid_timer.start()
		show_load_screen(game.title)
		current_game = game
		return true
	else:
		print("Missing game executable: ", executable_path)
		add_notice("Missing executable: " + game.executable)
		return false

func stop_game(pid: int) -> void:
	hide_load_screen()
	if current_game:
		log_game_end(current_game)
	current_game = null
	add_notice("Returned control to launcher.", verbose)
	if pid_watching < 0: return
	games_container.can_move = true
	OS.kill(pid)
	reset_automation()
	start_allow_launch_timer()

func on_pid_timer_timeout() -> void:
	if OS.is_process_running(pid_watching):
		if verbose_console or console_spam < console_spam_max:
			print("Running")
			console_spam += 1
	else:
		add_notice("Game stopped.", verbose)
		pid_timer.stop()
		pid_watching = -1
		games_container.can_move = true
		DisplayServer.window_move_to_foreground()
		reset_automation()
		hide_load_screen()
		log_game_end(current_game)
		current_game = null

func on_game_btn_focused(who: GameButton) -> void:
	hide_load_screen()

	if not who.properties.description:
		description.text = "No Description."
	else:
		description.text = who.properties.description
	
	title.text = who.properties.title
	
	show_attributes(who.properties)

	if not who.properties.file("background"): 
		#bg.texture = default_bg
		bg.blend_textures_animated(bg.get_shader_texture(1), default_bg, 0.4)
		return
	var texture: ImageTexture = who.load_image_texture(who.properties.file("background"))
	if not texture: 
		bg.blend_textures_animated(bg.get_shader_texture(1), default_bg, 0.4)
		#bg.texture = default_bg
		return
	bg.blend_textures_animated(bg.get_shader_texture(1), texture, 0.4)
	#bg.texture = texture

func on_game_btn_pressed(btn: GameButton) -> void:
	hide_load_screen()
	# If game already launched, don't launch another one
	if pid_watching > 0:
		stop_game(pid_watching)
		return
	if not allow_game_launch:
		add_notice("Just wait a second...")
		allow_game_launch = true
		return
	launch_game(btn.game_name)

func on_released_parsed(release: Dictionary) -> void:
	print("release: ", release["version"])

	if release["new"]:
		version_btn.text = "New version available: " + release["version"]
	else:
		version_btn.text = "You have the latest version: " + release["version"]
	version_btn.uri = release["url"]

func is_interactive():
	if pid_watching > 0:
		return false
	return games_container.can_move

func start_allow_launch_timer():
	# adds a 1 second delay before allowing launch...
	#  helpful for screensaver, and after quitting a game, to prevent launch
	allow_game_launch = false
	$Timers/AllowGameLaunchTimer.start()	

func _on_allow_game_launch_timer():
	allow_game_launch = true

# NOTICES

func add_notice(text: String, use_verbose := false, add_to_front := false) -> void:
	print(text)
	if verbose or not use_verbose:
		var notice: Notice = notice_tscn.instantiate()
		notice.text = text
		%Notices.add_child(notice)
		if add_to_front:
			%Notices.move_child(notice, 0)

# MOUSE - edge of screen scrolling

func _on_left_button_pressed() -> void:
	games_container.scroll_left()

func _on_right_button_pressed() -> void:
	games_container.scroll_right()

func _on_left_mouse_entered() -> void:
	games_container.scroll_left()

func _on_right_mouse_entered() -> void:
	games_container.scroll_right()

# OVERLAY

func setup_overlay():
	$Overlay.visible = false
	if launcher_config.has_section_key("LAUNCHER", "overlay"):
		$Overlay.visible = true
		var tex: ImageTexture = load_image_texture(launcher_config.get_value("LAUNCHER", "overlay"))
		if not tex: return
		$Overlay.texture = tex

func load_image_texture(path: String) -> ImageTexture:
	var capsule_im: Image = Image.new()
	if capsule_im.load(path) != OK:
		print("WARNING: Can't load texture: ", path)
		return null
	else:
		var tex: ImageTexture = ImageTexture.new()
		tex.set_image(capsule_im)
		return tex
		
# AUTOMATION

func reset_automation():
	if screensaver:
		stop_screensaver()
	if autoscroll:
		stop_autoscrolling()
		
# AUTOSCROLL

func autoscroll_setup():
	if autoscroll:
		if launcher_config.has_section_key("AUTOMATION", "autoscroll_time"):
			$Timers/AutoscrollTimer.wait_time = int(launcher_config.get_value("AUTOMATION", "autoscroll_time"))
		if launcher_config.has_section_key("AUTOMATION", "autoscroll_start_time"):
			$Timers/AutoscrollStartTimer.wait_time = int(launcher_config.get_value("AUTOMATION", "autoscroll_start_time"))

func _on_autoscroll_start_timer():
	if verbose:
		add_notice("Start autoscroll carousel...")
	$Timers/AutoscrollTimer.start()
		
func _on_autoscroll_timer():
	if is_interactive() and not is_screensaver_visible():
		if autoscroll_direction == 1:
			if not games_container.scroll_right():
				autoscroll_direction = -1
		else:
			if not games_container.scroll_left():
				autoscroll_direction = 1

func stop_autoscrolling():
	$Timers/AutoscrollTimer.stop()
	$Timers/AutoscrollStartTimer.start()

# SCREENSAVER

func screensaver_setup():
	$Screensaver.visible = false
	if screensaver:
		if launcher_config.has_section_key("AUTOMATION", "screensaver_title"):
			$Screensaver/ScreensaverTitle.text = launcher_config.get_value("AUTOMATION", "screensaver_title")
		if launcher_config.has_section_key("AUTOMATION", "screensaver_time"):
			$Timers/ScreensaverTimer.wait_time = int(launcher_config.get_value("AUTOMATION", "screensaver_time"))
		if launcher_config.has_section_key("AUTOMATION", "screensaver_image"):
			$Screensaver/ScreensaverImage.visible = true
			var tex: ImageTexture = load_image_texture(launcher_config.get_value("AUTOMATION", "screensaver_image"))
			if not tex: return
			$Screensaver/ScreensaverImage.texture = tex

func _on_screensaver_timer():
	if is_interactive():
		show_screensaver()
	else:
		$Timers/ScreensaverTimer.start()

func is_screensaver_visible():
	return $Screensaver.visible

func show_screensaver():
	if verbose:
		add_notice("Screensaver activating...")
	if screensaver_tween:
		screensaver_tween.kill()
	$Screensaver.modulate.a = 0.0
	screensaver_tween = create_tween()
	screensaver_tween.set_ease(Tween.EASE_OUT)
	screensaver_tween.tween_property($Screensaver, "modulate:a", 1.0, 3.0)
	$Screensaver.visible = true
	
func stop_screensaver():
	if screensaver_tween:
		screensaver_tween.kill()
		start_allow_launch_timer()
		screensaver_tween = null
	$Screensaver.visible = false
	$Timers/ScreensaverTimer.start()
	hide_load_screen()

# LOAD SCREEN

func hide_load_screen():
	%Loading.visible = false

func show_load_screen(game_name: String):
	%Loading.visible = true
	if game_name:
		%Loading/Labels/GameName.visible = true
		%Loading/Labels/GameName.text = game_name
	else:
		%Loading/Labels/GameName.visible = false

# ATTRIBUTES

func hide_attributes():
	for attribute: Attribute in %Attributes.get_children():
		attribute.visible = false

func show_attributes(game: Game):
	#print('ATTRIBUTES')
	#print(game.attributes)
	for attribute: Attribute in %Attributes.get_children():
		var attribute_name: String = attribute.name
		attribute.visible = false
		if attribute_name in game.attributes:
			if game.attributes[attribute_name]:
				attribute.visible = true

# LOG FILE

func log_game_start(game: Game):
	time_start = Time.get_unix_time_from_system() 
	var time_start_dict := Time.get_datetime_dict_from_unix_time(time_start) 
	var message: String = "Started: " + game.title + "\n"
	#message += "- "+game.executable + "\n" 
	message += "- " + util.time_date_dict_to_string(time_start_dict)
	_write_log(message)

func log_game_end(game: Game):
	time_end = Time.get_unix_time_from_system() 
	var time_end_dict := Time.get_datetime_dict_from_unix_time(time_end) 
	var time_elapsed := time_end - time_start
	#var time_elapsed_dict := Time.get_datetime_dict_from_unix_time(time_elapsed)
	var message: String = "Ended: " + game.title  + "\n"
	message += "- " + util.time_date_dict_to_string(time_end_dict) + "\n"
	message += "- Elapsed: " + util.time_to_string(time_elapsed)
	_write_log(message)

func _write_log(message: String):
	print("LOG: " + message)
	var file_dir := "user://"+log_file
	var file := FileAccess.open(file_dir, FileAccess.READ_WRITE)
	if file and file.is_open():
		file.seek_end()
		file.store_line(message)
		file.close()
	else:
		print("Cant open log file: " + file_dir)

# LAUNCHER CONFIG

func load_launcher_config() -> void:
	launcher_config = ConfigFile.new()
	# check for config in user:// first, then res://
	var _config_file = "user://" + launcher_config_file
	if not FileAccess.file_exists(_config_file):
		_config_file = "res://" + launcher_config_file
	if FileAccess.file_exists(_config_file):
		var status = launcher_config.load(_config_file)
		if status == OK:
			platform = launcher_config.get_value("LAUNCHER", "platform", platform)
			enforce_platform = launcher_config.get_value("LAUNCHER", "enforce_platform", enforce_platform)
			autoscan = launcher_config.get_value("LAUNCHER", "autoscan", autoscan)
			verbose = launcher_config.get_value("LAUNCHER", "verbose", verbose)
			verbose_console = launcher_config.get_value("LAUNCHER", "verbose_console", verbose_console)
			check_for_updates = launcher_config.get_value("LAUNCHER", "check_for_updates", check_for_updates)
			allow_mouse = launcher_config.get_value("LAUNCHER", "allow_mouse", allow_mouse)
			show_version = launcher_config.get_value("LAUNCHER", "show_version", show_version)
			screensaver = launcher_config.get_value("AUTOMATION", "screensaver", screensaver)
			autoscroll = launcher_config.get_value("AUTOMATION", "autoscroll", autoscroll)
			log_file = launcher_config.get_value("LOGGING", "log_file", log_file)
			print("SUCCESS: loaded launcher config file\n")
		else:
			print("WARNING: bad launcher config file ", status)

# TAG FILTERING

		# tag_container.anchor_left = 0.5
		# tag_container.anchor_right = 0.5
		# tag_container.offset_left = -200
		# tag_container.offset_right = 200

func setup_tag_filters() -> void:
	# Create tag filter container if it doesn't exist
	tag_container = $TagFilters
	if not tag_container:
		tag_container = HBoxContainer.new()
		tag_container.name = "TagFilters"
		tag_container.position.x = 10
		tag_container.position.y = 10
		tag_container.alignment = BoxContainer.ALIGNMENT_CENTER;
		add_child(tag_container)
	
	# Clear existing tag buttons
	for child in tag_container.get_children():
		child.queue_free()
	
	# Get all unique attributes from games
	var all_attributes = games_container.get_all_attributes()
	
	# Add spacing between buttons
	tag_container.add_theme_constant_override("separation", 20)
	
	# Create empty style for transparent buttons
	var empty_style = StyleBoxEmpty.new()
	
	# Add "All" button
	var all_button = Button.new()
	all_button.text = "All"
	all_button.pressed.connect(_on_tag_filter_pressed.bind(""))
	all_button.custom_minimum_size = Vector2(100, 40)
	all_button.add_theme_stylebox_override("normal", empty_style)
	all_button.add_theme_stylebox_override("hover", empty_style)
	all_button.add_theme_stylebox_override("pressed", empty_style)
	all_button.add_theme_stylebox_override("focus", empty_style)
	tag_container.add_child(all_button)
	
	# Add "Recently Added" button
	var recent_button = Button.new()
	recent_button.text = "Recently Added"
	recent_button.pressed.connect(_on_recent_filter_pressed)
	recent_button.custom_minimum_size = Vector2(100, 40)
	recent_button.add_theme_stylebox_override("normal", empty_style)
	recent_button.add_theme_stylebox_override("hover", empty_style)
	recent_button.add_theme_stylebox_override("pressed", empty_style)
	recent_button.add_theme_stylebox_override("focus", empty_style)
	tag_container.add_child(recent_button)
	
	# Add attribute buttons
	for attribute in all_attributes:
		var attribute_button = Button.new()
		var display_info = get_attribute_display_info(attribute)
		
		if display_info.icon >= 0:
			# Create button with icon
			attribute_button.custom_minimum_size = Vector2(120, 40)
			attribute_button.icon = create_attribute_icon(display_info.icon)
		else:
			attribute_button.custom_minimum_size = Vector2(100, 40)
		
		attribute_button.text = display_info.name
		attribute_button.pressed.connect(_on_attribute_filter_pressed.bind(attribute))
		attribute_button.add_theme_stylebox_override("normal", empty_style)
		attribute_button.add_theme_stylebox_override("hover", empty_style)
		attribute_button.add_theme_stylebox_override("pressed", empty_style)
		attribute_button.add_theme_stylebox_override("focus", empty_style)
		tag_container.add_child(attribute_button)
	
	# Update tag button focus
	update_tag_button_focus()

func _on_tag_filter_pressed(tag: String) -> void:
	print("DEBUG: Tag filter pressed: ", tag)
	games_container.filter_by_tag(tag, game_button)
	
	# Reconnect button signals after filtering
	var buttons = games_container.get_children()
	print("DEBUG: Found ", buttons.size(), " game buttons after filtering")
	for b: GameButton in buttons:
		if not b.focused.is_connected(on_game_btn_focused):
			b.focused.connect(on_game_btn_focused)
		if not b.pressed.is_connected(on_game_btn_pressed.bind(b)):
			b.pressed.connect(on_game_btn_pressed.bind(b))
	
	# Auto-select first game to trigger hard refresh
	auto_select_first_game()
	
	# Switch back to carousel mode
	tag_filter_focused = false

func _on_recent_filter_pressed() -> void:
	games_container.filter_by_recent_date(game_button)  # Sort by date (no threshold)
	
	# Reconnect button signals after filtering
	var buttons = games_container.get_children()
	for b: GameButton in buttons:
		if not b.focused.is_connected(on_game_btn_focused):
			b.focused.connect(on_game_btn_focused)
		if not b.pressed.is_connected(on_game_btn_pressed.bind(b)):
			b.pressed.connect(on_game_btn_pressed.bind(b))
	
	# Auto-select first game to trigger hard refresh
	auto_select_first_game()
	
	# Switch back to carousel mode
	tag_filter_focused = false

func _on_attribute_filter_pressed(attribute: String) -> void:
	print("DEBUG: Attribute filter pressed: ", attribute)
	games_container.filter_by_attribute(attribute, game_button)
	
	# Reconnect button signals after filtering
	var buttons = games_container.get_children()
	print("DEBUG: Found ", buttons.size(), " game buttons after filtering")
	for b: GameButton in buttons:
		if not b.focused.is_connected(on_game_btn_focused):
			b.focused.connect(on_game_btn_focused)
		if not b.pressed.is_connected(on_game_btn_pressed.bind(b)):
			b.pressed.connect(on_game_btn_pressed.bind(b))
	
	# Auto-select first game to trigger hard refresh
	auto_select_first_game()
	
	# Switch back to carousel mode
	tag_filter_focused = false

func handle_tag_navigation(event: InputEvent) -> void:
	if not tag_container or tag_container.get_child_count() == 0:
		return
	
	# Switch to tag filter mode with up arrow
	if event.is_action_pressed("ui_up") and not tag_filter_focused:
		tag_filter_focused = true
		current_tag_index = 0
		update_tag_button_focus()
		get_viewport().set_input_as_handled()
		return
	
	# Switch back to game carousel with down arrow
	if event.is_action_pressed("ui_down") and tag_filter_focused:
		tag_filter_focused = false
		games_container.focus_selected()
		get_viewport().set_input_as_handled()
		return
	
	# Handle tag navigation when focused
	if tag_filter_focused:
		if event.is_action_pressed("ui_left"):
			current_tag_index = max(0, current_tag_index - 1)
			update_tag_button_focus()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			current_tag_index = min(tag_container.get_child_count() - 1, current_tag_index + 1)
			update_tag_button_focus()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_accept"):
			# Activate the currently focused tag button
			var tag_button = tag_container.get_child(current_tag_index)
			if tag_button is Button:
				tag_button.emit_signal("pressed")
			get_viewport().set_input_as_handled()

func update_tag_button_focus() -> void:
	if not tag_container:
		return
	
	# Clear focus from all tag buttons
	for child in tag_container.get_children():
		if child is Button:
			child.modulate = Color.WHITE
			child.scale = Vector2.ONE
	
	# Highlight and expand the currently focused tag button
	if current_tag_index >= 0 and current_tag_index < tag_container.get_child_count():
		var focused_button = tag_container.get_child(current_tag_index)
		if focused_button is Button:
			focused_button.modulate = Color.YELLOW
			focused_button.scale = Vector2(1.1, 1.1)

func auto_select_first_game() -> void:
	# Get the first game button from the filtered list
	var game_buttons = games_container.get_children()
	if game_buttons.size() > 0:
		var first_game_button = game_buttons[0] as GameButton
		if first_game_button:
			# Set the carousel selected index
			games_container.selected_idx = 0
			# Force focus on the first game button (this will handle everything)
			call_deferred("_force_focus_first_game", first_game_button)

func update_ui_with_game(game: Game) -> void:
	# Update title and description
	if not game.description:
		description.text = "No Description."
	else:
		description.text = game.description
	
	title.text = game.title
	
	# Update attributes
	show_attributes(game)
	
	# Update background image
	if not game.file("background"): 
		bg.blend_textures_animated(bg.get_shader_texture(1), default_bg, 0.4)
		return
	var texture: ImageTexture = load_image_texture(game.file("background"))
	if not texture: 
		bg.blend_textures_animated(bg.get_shader_texture(1), default_bg, 0.4)
		return
	bg.blend_textures_animated(bg.get_shader_texture(1), texture, 0.4)

func _force_focus_first_game(first_game_button: GameButton) -> void:
	# Ensure the first game button gets focus
	if is_instance_valid(first_game_button):
		print("DEBUG: Forcing focus on first game: ", first_game_button.properties.title)
		# Set focus and trigger all visual effects
		first_game_button.grab_focus()
		# Trigger the scale animation
		first_game_button.toggle_focus_visuals(true)
		# Call the focus handler to update UI
		on_game_btn_focused(first_game_button)

func _trigger_ui_update(btn: GameButton) -> void:
	# Force the UI update by calling the focus handler directly
	on_game_btn_focused(btn)

# ATTRIBUTE ICON HELPERS

func get_attribute_display_info(attribute: String) -> Dictionary:
	# Map attribute names to display info (name and icon frame) from app.tscn
	match attribute.to_lower():
		"singleplayer":
			return {"name": "Single Player", "icon": 73}
		"multiplayer":
			return {"name": "Two Players", "icon": 98}
		"pvp":
			return {"name": "Competitive", "icon": 25}
		"coop":
			return {"name": "Cooperative", "icon": 15}
		"trackball":
			return {"name": "Trackball", "icon": 43}
		"leaderboards":
			return {"name": "Leaderboards", "icon": 3}
		"gamejam":
			return {"name": "Game Jam Entry", "icon": 16}
		"arcadejam":
			return {"name": "Arcade Jam Entry", "icon": 81}
		"construction":
			return {"name": "Unfinished", "icon": 102}
		"crashy":
			return {"name": "Crashy", "icon": 76}
		_:
			return {"name": attribute.capitalize(), "icon": -1}

func get_attribute_icon(attribute: String) -> int:
	var info = get_attribute_display_info(attribute)
	return info.icon

func create_attribute_icon(frame: int) -> Texture2D:
	# Create a temporary sprite to extract the frame, just like the Attribute scene does
	var sprite = Sprite2D.new()
	var sprite_sheet = preload("res://scenes/icons/sheet_white2x.png")
	sprite.texture = sprite_sheet
	sprite.hframes = 6
	sprite.vframes = 20
	sprite.frame = frame
	
	# Get the region of the sprite sheet for this frame
	var texture_size = sprite_sheet.get_size()
	var frame_width = texture_size.x / 6
	var frame_height = texture_size.y / 20
	var frame_x = (frame % 6) * frame_width
	var frame_y = int(frame / 6) * frame_height
	
	# Extract the frame
	var image = sprite_sheet.get_image()
	var frame_image = image.get_region(Rect2i(frame_x, frame_y, frame_width, frame_height))
	
	# Create texture from frame and scale it down to half size
	var texture = ImageTexture.new()
	texture.set_image(frame_image)
	
	# Scale the image down to half size
	var scaled_image = frame_image.duplicate()
	scaled_image.resize(frame_width / 2, frame_height / 2)
	var scaled_texture = ImageTexture.new()
	scaled_texture.set_image(scaled_image)
	return scaled_texture
