extends Resource
class_name DialogueData

@export var text_file_path: String

@export var colors: Dictionary = {
	"Text": Color("#FFFFFF"),
	"Outline": Color("#000000")
}

@export var music_tracks: Dictionary = {
	
}

@export var strings: Dictionary = {
	"MusicBus": "Master"
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
	# Timer intervals (in seconds)
	"TypingTimerInterval": 0.1,
	"RippleTimerInterval": 0.016,
	"EffectUpdateTimerInterval": 0.016,
	# Text layout
	"LineHeightMultiplier": 1.2,  # Font size * this = line height
	# Audio
	"AudioPitchMin": 0.9,
	"AudioPitchMax": 1.1,
	"MusicBaseVolume": -10.0,
	"MusicDefaultFadeDuration": 1.0,
	# Effects
	"RippleStrengthMultiplier": 0.4,
	"DefaultJitterIntensity": 2,
	"DefaultWiggleIntensity": 5,
	"DefaultShakeIntensity": 3,
	# Entrance animation
	"EntranceFadeDuration": 1.0,
	# Popup animation
	"PopupScaleDuration": 0.3,
	"PopupFadeInDuration": 0.2,
	"PopupDisplayDuration": 0.8,
	"PopupFadeOutDuration": 0.4,
	"PopupInitialScale": 0.1,
	"PopupSizeMultiplier": 0.8,  # Screen size * this = max popup size
	# Choice UI
	"ChoiceBaseHeight": 100,
	"ChoiceHeightPerOption": 60,
	# Frame rate conversion
	"FramesPerSecond": 60,
	# Effect timing
	"WiggleTimeMultiplier": 0.01,
}

@export var theme: Dictionary = {
	
}

func get_color(color_key: String) -> Color:
	if color_key in colors:
		return colors[color_key]
	return Color.WHITE

func get_integer(int_key: String, default_value: int = 0) -> int:
	if int_key in integers:
		return integers[int_key]
	return default_value

func get_float(int_key: String, default_value: float = 0.0) -> float:
	if int_key in integers:
		return float(integers[int_key])
	return default_value

func get_string(string_key: String, default_value: String = "") -> String:
	if string_key in strings:
		return strings[string_key]
	return default_value
