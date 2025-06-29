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
	
func manually_add_games(path: String) -> void:
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
