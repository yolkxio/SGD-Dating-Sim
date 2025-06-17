extends Control

@export var dialogue_data: DialogueData

var full_dialogue_segments: Array = []
var current_segment_index: int = 0
var current_segment_text: String = ""
var current_displayed_text: String = ""
var typing_timer: Timer
var is_typing: bool = false
var current_position: int = 0
var words_array: Array = []
var current_word_index: int = 0
var waiting_for_input: bool = false

var dialogue_text: RichTextLabel
var button: TextureButton

func _ready():
	if dialogue_data:
		typing_system()
		dialogue_box()
		connect_button()

func typing_system():
	typing_timer = Timer.new()
	add_child(typing_timer)
	typing_timer.timeout.connect(_on_typing_timer_timeout)
	typing_timer.wait_time = 0.1

func dialogue_box():
	dialogue_text = $TextContainer/TextBackground/MarginContainer/RichTextLabel
	apply_formatting()
	load_dialogue()

func connect_button():
	button = $TextContainer/TextureButton
	if button:
		button.pressed.connect(_button)

func apply_formatting():
	if not dialogue_text:
		return
	
	var font_size = dialogue_data.integers["FontSize"]
	dialogue_text.add_theme_font_size_override("normal_font_size", font_size)
	
	dialogue_text.add_theme_color_override("default_color", dialogue_data.get_color("Text"))
	
	var outline_size = dialogue_data.integers["OutlineSize"]
	if outline_size > 0:
		dialogue_text.add_theme_constant_override("outline_size", outline_size)
		dialogue_text.add_theme_color_override("font_outline_color", dialogue_data.get_color("Outline"))

func load_dialogue():
	var file_path = dialogue_data.text_file_path
	var file_content = ""
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	file_content = file.get_as_text()
	file.close()
	
	parse_dialogue(file_content)
	
	if full_dialogue_segments.size() > 0:
		start_next()

func parse_dialogue(content: String):
	full_dialogue_segments.clear()
	current_segment_index = 0
	
	var raw_segments = content.split("<>")
	
	for segment in raw_segments:
		var cleaned_segment = segment.strip_edges()
		
		if cleaned_segment.length() > 0:
			full_dialogue_segments.append(cleaned_segment)

func start_next():
	if current_segment_index >= full_dialogue_segments.size():
		return
	
	if is_typing:
		return
	
	current_segment_text = full_dialogue_segments[current_segment_index]
	current_displayed_text = ""
	current_position = 0
	current_word_index = 0
	is_typing = true
	waiting_for_input = false
	
	dialogue_text.text = ""
	
	var delay_between_chars = dialogue_data.integers["DelayBetweenCharacters"]
	
	if delay_between_chars > 0:
		typing_timer.wait_time = delay_between_chars / 60.0
	else:
		var text_speed = dialogue_data.integers["TextSpeed"]
		typing_timer.wait_time = (60.0 / text_speed)
		
		setup_word_array()
	
	var initial_delay = dialogue_data.integers["Delay"]
	if initial_delay > 0:
		var initial_wait = initial_delay / 60.0
		await get_tree().create_timer(initial_wait).timeout
	
	typing_timer.start()

func setup_word_array():
	words_array = []
	var words = current_segment_text.split(" ")
	for i in range(words.size()):
		words_array.append(words[i])
		if i < words.size() - 1:
			words_array.append(" ")

func _on_typing_timer_timeout():
	var delay_between_chars = dialogue_data.integers["DelayBetweenCharacters"]
	button.visible = false
	
	if delay_between_chars > 0:
		while current_position < current_segment_text.length():
			var char = current_segment_text[current_position]
			current_displayed_text += char
			current_position += 1
			
			if char != " ":
				break
		
		dialogue_text.text = current_displayed_text
		
		if current_position >= current_segment_text.length():
			finish_current()
	else:
		if current_word_index < words_array.size():
			current_displayed_text += words_array[current_word_index]
			current_word_index += 1
			dialogue_text.text = current_displayed_text
		else:
			finish_current()

func finish_current():
	is_typing = false
	typing_timer.stop()
	dialogue_text.text = current_segment_text
	waiting_for_input = true
	button.visible = true

func next():
	if not waiting_for_input:
		return
	
	current_segment_index += 1
	start_next()

func skip():
	if is_typing:
		is_typing = false
		typing_timer.stop()
		dialogue_text.text = current_segment_text
		waiting_for_input = true

func _button():
	if is_typing:
		skip()
	elif waiting_for_input:
		next()

func _input(event):
	if event.is_action_pressed("Skip button"):
		if is_typing:
			skip()
		elif waiting_for_input:
			next()
