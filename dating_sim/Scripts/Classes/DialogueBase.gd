
extends Resource
class_name DialogueData

@export var text_file_path: String

@export var colors: Dictionary = {
	"Text": Color("#FFFFFF"),
	"Outline": Color("#000000")
}

@export var fonts: Dictionary = {
	
}

@export var integers: Dictionary = {
	"TextSpeed": 100,
	"FontSize": 32,
	"Delay": 0,
	"PauseTimer": 0,
	"DelayBetweenCharacters": 0,
	"AddedSpacing": 0,
	"OutlineSize": 0,
	"RippleFrames": 0,
}

@export var theme: Dictionary = {
	
}

func get_color(color_key: String) -> Color:
	if color_key in colors:
		return colors[color_key]
	return Color.WHITE
