extends Control
class_name NameTag

@export var character_data: CharacterData
@export var padding: Vector2 = Vector2(20, 10)  # Horizontal and vertical padding
@export var min_width: float = 100.0  # Minimum width for the name tag
@export var font_size: int = 32  # Font size for the name

var name_panel: Panel
var name_label: Label

func _ready():
	setup_name_tag()

func setup_name_tag():
	name_panel = find_child("Panel") as Panel
	name_label = find_child("Label") as Label
	
	if not name_panel or not name_label:
		return
	
	name_panel.position = Vector2.ZERO
	name_label.position = Vector2.ZERO
	
	if character_data:
		call_deferred("update_name_tag")

func set_character(new_character_data: CharacterData):
	character_data = new_character_data
	call_deferred("update_name_tag")

func update_name_tag():
	if not character_data or not name_label or not name_panel:
		return
	
	# Set the character name
	var character_name = character_data.character_name
	if character_name.is_empty():
		character_name = "Unknown"
	
	name_label.text = character_name
	
	# Calculate the required size
	calculate_and_resize()

func calculate_and_resize():
	if not name_label or not name_panel:
		return
	
	# Get the font
	var font = name_label.get_theme_font("font")
	if not font:
		font = ThemeDB.fallback_font
		if not font:
			return
	
	# Get the text size
	var text_size = font.get_string_size(
		name_label.text, 
		HORIZONTAL_ALIGNMENT_LEFT, 
		-1, 
		font_size
	)
	
	# Calculate the required panel size with padding
	var required_width = max(text_size.x + padding.x * 2, min_width)
	var required_height = text_size.y + padding.y * 2
	
	# Resize everything
	name_panel.set_deferred("size", Vector2(required_width, required_height))
	name_label.set_deferred("size", Vector2(required_width, required_height))
	name_label.set_deferred("position", Vector2.ZERO)
	set_deferred("size", Vector2(required_width, required_height))

func set_font_size(new_font_size: int):
	font_size = new_font_size
	if name_label:
		name_label.add_theme_font_size_override("font_size", font_size)
		call_deferred("calculate_and_resize")

func set_padding(new_padding: Vector2):
	padding = new_padding
	call_deferred("calculate_and_resize")

func set_min_width(new_min_width: float):
	min_width = new_min_width
	call_deferred("calculate_and_resize")

func refresh():
	call_deferred("update_name_tag")
