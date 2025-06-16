extends Control

@export var dialogue_data: DialogueData

func _ready():
	if dialogue_data:
		setup_dialogue_box()

func setup_dialogue_box():
	var text_bg = $TextContainer/TextBackground
	var text = $TextContainer/TextBackground/MarginContainer/Text

	text_bg.modulate = Color(dialogue_data.hex_colors["background"])
	text.modulate = Color(dialogue_data.hex_colors["text_main"])
