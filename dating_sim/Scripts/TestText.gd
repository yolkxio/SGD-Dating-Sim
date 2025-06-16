extends Control

@export var dialogue_data: DialogueData

func _ready():
	if dialogue_data:
		setup_dialogue_box()

func setup_dialogue_box():
	var dialogue_text = $TextContainer/TextBackground/MarginContainer/RichTextLabel
	
	var font_size = dialogue_data.integers["FontSize"]
	var text_color = dialogue_data.get_color("Text")
	var outline_size = dialogue_data.integers["OutlineSize"]
	var text_speed = dialogue_data.integers["TextSpeed"]
	var delay = dialogue_data.integers["Delay"]
	var delay_between_chars = dialogue_data.integers["DelayBetweenCharacters"]
	
	if outline_size > 0:
		dialogue_text.add_theme_constant_override("outline_size", outline_size)
		dialogue_text.add_theme_color_override("font_outline_color", dialogue_data.get_color("Outline"))
	dialogue_text.add_theme_font_size_override("normal_font_size", font_size)
	dialogue_text.add_theme_color_override("default_color", text_color)
	
