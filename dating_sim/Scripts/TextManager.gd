extends Node
class_name TextManager

var dialogue_data: DialogueData
var text_container: Control
var text_labels: Array = []

# Current segment data
var current_segment_text: String = ""
var current_segment_effects: Array = []
var current_position: int = 0

func initialize(data: DialogueData, container: Control):
	dialogue_data = data
	text_container = container

func prepare_segment(segment_text: String, segment_effects: Array):
	current_segment_text = segment_text
	current_segment_effects = segment_effects
	current_position = 0
	
	clear_all_text()
	
	# Create ALL labels at once, invisible
	create_all_labels()

func create_all_labels():
	var x_position = 0.0
	var y_position = 0.0
	var font_size = dialogue_data.integers["FontSize"]
	var line_height = font_size * dialogue_data.get_float("LineHeightMultiplier", 1.2)
	
	for i in range(current_segment_text.length()):
		var char = current_segment_text[i]
		
		if char == "\n":
			y_position += line_height
			x_position = 0.0
			continue
		
		var char_label = Label.new()
		char_label.text = char
		char_label.add_theme_font_size_override("font_size", font_size)
		char_label.add_theme_color_override("font_color", dialogue_data.get_color("Text"))
		
		var outline_size = dialogue_data.integers["OutlineSize"]
		if outline_size > 0:
			char_label.add_theme_constant_override("outline_size", outline_size)
			char_label.add_theme_color_override("font_outline_color", dialogue_data.get_color("Outline"))
		
		char_label.position = Vector2(x_position, y_position)
		char_label.modulate.a = 0.0  # Start invisible
		text_container.add_child(char_label)
		text_labels.append(char_label)
		
		var actual_width = get_char_width(char, font_size)
		x_position += actual_width

func get_char_width(char: String, font_size: int) -> float:
	var temp_label = Label.new()
	temp_label.add_theme_font_size_override("font_size", font_size)
	temp_label.text = char
	add_child(temp_label)
	temp_label.force_update_transform()
	var char_size = temp_label.get_theme_font("font").get_string_size(char, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	remove_child(temp_label)
	temp_label.queue_free()
	return char_size.x

func show_next_character() -> bool:
	if current_position < text_labels.size():
		text_labels[current_position].modulate.a = 1.0
		current_position += 1
		return current_position < text_labels.size()
	return false

func show_next_word() -> bool:
	var start_position = current_position
	
	# Handle newlines first
	if current_position < text_labels.size() and current_position < current_segment_text.length() and current_segment_text[current_position] == "\n":
		text_labels[current_position].modulate.a = 1.0
		current_position += 1
		return current_position < text_labels.size()
	
	# Skip spaces at current position
	while current_position < text_labels.size() and current_position < current_segment_text.length() and current_segment_text[current_position] == " ":
		text_labels[current_position].modulate.a = 1.0
		current_position += 1
	
	# Show characters until next space, newline, or end
	while current_position < text_labels.size() and current_position < current_segment_text.length():
		var char = current_segment_text[current_position]
		if char == " " or char == "\n":
			break
		text_labels[current_position].modulate.a = 1.0
		current_position += 1
	
	# If we didn't advance at all, we're at the end
	if current_position == start_position and current_position < text_labels.size():
		# Force advance to prevent infinite loop
		text_labels[current_position].modulate.a = 1.0
		current_position += 1
	
	return current_position < text_labels.size()

func get_current_position() -> int:
	return current_position

func get_text_labels() -> Array:
	return text_labels

func clear_all_text():
	for label in text_labels:
		if is_instance_valid(label):
			label.queue_free()
	text_labels.clear()

func finish_rendering():
	for label in text_labels:
		if is_instance_valid(label):
			label.modulate.a = 1.0
