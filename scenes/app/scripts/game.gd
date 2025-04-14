# GAME
extends Object
class_name Game

# SUBDIRECTORY (identifier)
var subdirectory: String
var subdirectory_path: String

# PROPERTIES
var title: String
var executable: String
var description: String
var capsule: String
var background: String
var platform: String
var arguments: PackedStringArray

var animated_capsule: String
var animated_capsule_hframes: int
var animated_capsule_vframes: int
var animated_capsule_frame_count: int
var animated_capsule_frame_rate: int

# CONFIG
var config: ConfigFile

# SETTINGS
var order: int
var category := []
var visible := true
var available := false
var pinned := false

# ATTRIBUTES
var attributes: Dictionary = {}

# INTERNAL
var sort_order: int

# Return a file with the full directory included
func file(property: String) -> String:
	if property in self:
		return subdirectory_path.path_join(get(property))
	else:
		print("ERROR: missing file property in game object ", property)
		return ''

# Apply config values if we have them
func parse_config():
	title = executable
	if not config:
		return
	title = config.get_value("GAME", "title", title)
	executable = config.get_value("GAME", "executable", executable)
	description = config.get_value("GAME", "description", description)
	capsule = config.get_value("GAME", "capsule", capsule)
	background = config.get_value("GAME", "background", background)

	animated_capsule = config.get_value("ANIMATED CAPSULE", "sprite_sheet", animated_capsule)
	animated_capsule_hframes = config.get_value("ANIMATED CAPSULE", "horizontal_frames", 1)
	animated_capsule_vframes = config.get_value("ANIMATED CAPSULE", "vertical_frames", 1)
	animated_capsule_frame_count = config.get_value("ANIMATED CAPSULE", "frame_count", 1)
	animated_capsule_frame_rate = config.get_value("ANIMATED CAPSULE", "frame_rate", 12)

	category = config.get_value("GAME", "category", [])
	order = config.get_value("SETTINGS", "order", 0)
	visible = config.get_value("SETTINGS", "visible", true)
	available = config.get_value("SETTINGS", "available", true)
	pinned = config.get_value("SETTINGS", "pinned", true)
	for key in config.get_section_keys("ATTRIBUTES"):
		attributes[key] = config.get_value("ATTRIBUTES", key)

	var arguments_string = config.get_value("GAME", "arguments", "")
	arguments = arguments_string.split(" ")
	
func debug_line() -> String:
	return "\t\t" + title + " -> \t\t\t" + executable
