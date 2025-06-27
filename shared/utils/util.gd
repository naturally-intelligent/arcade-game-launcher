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
