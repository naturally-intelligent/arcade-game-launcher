# UTILITY FUNCTIONS
#  taken from Chore Engine
#  https://github.com/naturally-intelligent/chore-4
extends Node

func time_to_string(time: float, show_milliseconds := false) -> String:
	var seconds := floori(fmod(time, 60))
	var minutes := floori(time / 60)
	var hours := floori(minutes / 60)
	var text := ''
	if hours > 0:
		text = "%d:%02d:%02d" % [hours, minutes, seconds]
	else:
		text = "%d:%02d" % [minutes, seconds]
	if show_milliseconds:
		var millis := int(fmod(time, 1)*100)
		text += ".%02d" % [millis]
	return text

func date_dict_to_string(date_dict: Dictionary) -> String:
	var formatted_date: String = "%02d-%02d-%04d" % [date_dict["month"], date_dict["day"], date_dict["year"]]
	return formatted_date

func time_dict_to_string(time_dict: Dictionary) -> String:
	var formatted_time: String = "%02d:%02d:%02d" % [time_dict["hour"], time_dict["minute"], time_dict["second"]]
	return formatted_time

func time_date_dict_to_string(date_dict: Dictionary) -> String:
	return date_dict_to_string(date_dict) + ' ' + time_dict_to_string(date_dict)

func string_to_bool(_s: String) -> bool:
	if _s.to_lower() == 'true':
		return true
	else:
		return false

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

func load_image_texture(path: String) -> ImageTexture:
	var loaded_image: Image = Image.new()
	if !FileAccess.file_exists(path) || loaded_image.load(path) != OK:
		push_warning("Failed to load image texture at: ", path)
		return null
	else:
		var image_texture: ImageTexture = ImageTexture.new()
		image_texture.set_image(loaded_image)
		return image_texture
		
		
