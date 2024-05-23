# APP
extends Control

@export var game_button: PackedScene
@export var default_bg: Texture
@export_enum("windows", "linux") var platform := "windows"
@export var enforce_platform := false
@export var verbose := true
@export var autoscan := true
@export var verbose_console := true

var pid_watching: int = -1
var games: Dictionary
var console_spam := 0
const console_spam_max = 3

@onready var bg: TextureRect = $BG
@onready var timer: Timer = Timer.new()
@onready var games_container: GamesCarousel = $Games
@onready var no_game_found = $NoGameFound
@onready var title: Label = $Description/Title
@onready var description: Label = $Description/Description
@onready var version_btn = $VersionBtn

@onready var check_for_updates := true
@onready var update_checker := UpdateChecker.new()

var launcher_config: ConfigFile
var launcher_config_file := "res://launcher.ini"

const notice_tscn = preload("res://scenes/notice/notice.tscn")

func _ready() -> void:
	# LAUNCHER CONFIG (optional)
	load_launcher_config()
	
	# UPDATES
	if check_for_updates:
		add_child(update_checker)
		update_checker.get_latest_version()
		update_checker.release_parsed.connect(on_released_parsed)
	
	# SETUP
	configure_timer()
	var base_dir: String = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	create_game_folder(base_dir)
	manually_add_games(base_dir.path_join("games"))
	if autoscan:
		scan_for_games(base_dir.path_join("games"))
	
	# PRINT
	print_games_to_console()
	
	# WARNINGS
	if games.is_empty():
		no_game_found.visible = true
	
	# UI
	var buttons: Array = games_container.create_game_buttons(game_button, games)
	for b in buttons:
		b.focused.connect(on_game_btn_focused)
		b.pressed.connect(on_game_btn_pressed.bind(b))
	
	# Test
	#launch_game("Dashpong")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		print("About to quit, killing process")
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

func configure_timer() -> void:
	add_child(timer)
	# Configure the timer
	timer.one_shot = false
	timer.wait_time = 1.0
	timer.timeout.connect(on_timer_timeout)

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
						var content = text_file.get_as_text()
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
	if not game.executable: 
		add_notice("No executable set for game: " + game.title)
		return false
	var executable_path: String = game.file("executable")
	if FileAccess.file_exists(executable_path):
		games_container.can_move = false
		pid_watching = OS.create_process(executable_path, [])
		timer.start()
		return true
	else:
		print("Missing game executable: ", executable_path)
		add_notice("Missing executable: " + game.executable)
		return false

func stop_game(pid: int) -> void:
	add_notice("Returned control to launcher.", verbose)
	if pid_watching < 0: return
	games_container.can_move = true
	OS.kill(pid)

func on_timer_timeout() -> void:
	if OS.is_process_running(pid_watching):
		if verbose_console or console_spam < console_spam_max:
			print("Running")
			console_spam += 1
	else:
		add_notice("Game stopped.", verbose)
		timer.stop()
		pid_watching = -1
		games_container.can_move = true
		DisplayServer.window_move_to_foreground()

func on_game_btn_focused(who: Button) -> void:
	if not who.properties.description:
		description.text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
	else:
		description.text = who.properties.description
	
	title.text = who.properties.title

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

func on_game_btn_pressed(btn: Button) -> void:
	# If game already launched, don't launch another one
	if pid_watching > 0:
		stop_game(pid_watching)
		return
	launch_game(btn.game_name)

func on_released_parsed(release: Dictionary) -> void:
	print("release: ", release["version"])

	if release["new"]:
		version_btn.text = "New version available: " + release["version"]
	else:
		version_btn.text = "You have the latest version: " + release["version"]
	version_btn.uri = release["url"]

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

# LAUNCHER CONFIG

func load_launcher_config() -> void:
	launcher_config = ConfigFile.new()
	if FileAccess.file_exists(launcher_config_file):
		var status = launcher_config.load(launcher_config_file)
		if status == OK:
			platform = launcher_config.get_value("LAUNCHER", "platform", "windows")
			enforce_platform = launcher_config.get_value("LAUNCHER", "enforce_platform", true)
			autoscan = launcher_config.get_value("LAUNCHER", "autoscan", true)
			verbose = launcher_config.get_value("LAUNCHER", "verbose", true)
			verbose_console = launcher_config.get_value("LAUNCHER", "verbose_console", true)
			check_for_updates = launcher_config.get_value("LAUNCHER", "check_for_updates", true)
			print("SUCCESS: loaded launcher config file\n")
		else:
			print("WARNING: bad launcher config file ", status)
		
