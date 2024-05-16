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
	category = config.get_value("GAME", "category", [])
	order = config.get_value("SETTINGS", "order", 0)
	visible = config.get_value("SETTINGS", "visible", true)
	available = config.get_value("SETTINGS", "available", true)
	pinned = config.get_value("SETTINGS", "pinned", true)
	for key in config.get_section_keys("ATTRIBUTES"):
		attributes[key] = config.get_value("ATTRIBUTES", key)
	
func debug_line() -> String:
	return title + " -> " + executable
