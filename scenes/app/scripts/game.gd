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

# TAGS
var tags: Array[String] = []

# DATE
var date_added: String = ""

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
	
	# Load tags from config
	if config.has_section("TAGS"):
		var tags_value = config.get_value("TAGS", "list", [])
		if typeof(tags_value) == TYPE_STRING:
			# Handle comma-separated string format
			var tags_array = tags_value.split(",")
			tags.clear()
			for tag in tags_array:
				tags.append(tag.strip_edges())
		elif typeof(tags_value) == TYPE_ARRAY:
			tags.clear()
			for tag in tags_value:
				tags.append(str(tag))
	
	# Load date from config
	date_added = config.get_value("GAME", "date_added", "")
	
	var arguments_string = config.get_value("GAME", "arguments", "")
	arguments = arguments_string.split(" ")
	
func debug_line() -> String:
	return "\t\t" + title + " -> \t\t\t" + executable
