extends Control

@export var dialogue_data: DialogueData

var full_dialogue_segments: Array = []
var current_segment_index: int = 0
var current_segment_text: String = ""
var current_segment_effects: Array = []
var typing_timer: Timer
var is_typing: bool = false
var current_position: int = 0
var words_array: Array = []
var current_word_index: int = 0
var waiting_for_input: bool = false
var text_labels: Array = []
var banished_labels: Array = []
var text_container: Control
var is_word_mode: bool = false
var current_segment_word_positions: Array = []
var next_text_position: Vector2 = Vector2.ZERO
var current_ripple_frames: int = 0
var current_char_delay: int = 0
var current_word_speed: int = 0
var ripple_timer: Timer
var ripple_positions: Array = []
var icon_button: TextureButton

func _ready():
	typing_system()
	dialogue_box()
	connect_button()

func typing_system():
	typing_timer = Timer.new()
	add_child(typing_timer)
	typing_timer.timeout.connect(_render_timer)
	typing_timer.wait_time = 0.1
	ripple_timer = Timer.new()
	add_child(ripple_timer)
	ripple_timer.timeout.connect(_ripple_timer)
	ripple_timer.wait_time = 0.016
	ripple_timer.start()

func dialogue_box():
	text_container = $TextContainer/TextBackground/MarginContainer/TextContainer
	load_text()

func connect_button():
	icon_button = $TextContainer/TextureButton
	if icon_button:
		icon_button.pressed.connect(_button)

func load_text():
	var file_path = dialogue_data.text_file_path
	var file_content = ""
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		file_content = file.get_as_text()
		file.close()
	
	parse_text(file_content)
	
	if full_dialogue_segments.size() > 0:
		start_next()

func parse_text(content: String):
	full_dialogue_segments.clear()
	current_segment_index = 0
	var raw_segments = content.split("<>")
	
	for segment in raw_segments:
		var cleaned_segment = segment.strip_edges()
		if cleaned_segment.length() > 0:
			var parsed_data = find_effects(cleaned_segment)
			full_dialogue_segments.append(parsed_data)

func find_effects(segment_text: String) -> Dictionary:
	var clean_text = ""
	var effects_data = []
	var i = 0
	
	while i < segment_text.length():
		var char = segment_text[i]
		
		if char == "[":
			var end_bracket = segment_text.find("]", i)
			if end_bracket != -1:
				var effect_content = segment_text.substr(i + 1, end_bracket - i - 1)
				var new_effects = parse_effects(effect_content)
				
				effects_data.append({
					"position": clean_text.length(),
					"effects": new_effects
				})
				i = end_bracket + 1
				continue
		
		clean_text += char
		i += 1
	
	return {
		"text": clean_text,
		"effects": effects_data
	}

func parse_effects(effect_str: String) -> Dictionary:
	var effects = {
		"ripple": dialogue_data.integers.get("RippleFrames", 0),
		"char_delay": dialogue_data.integers.get("DelayBetweenCharacters", 0),
		"word_speed": dialogue_data.integers.get("TextSpeed", 500),
		"delay": 0
	}
	var effect_parts = effect_str.split(",")
	if effect_str == "":
		print("Reset to defaults at position")
		return effects
	
	for part in effect_parts:
		part = part.strip_edges()
		start_effects(part, effects)
	
	return effects

func start_effects(effect_str: String, effects: Dictionary):
	if effect_str.begins_with("!"):
		var number_str = effect_str.substr(1)
		var ripple_value = number_str.to_int()
		effects["ripple"] = ripple_value
	elif effect_str.begins_with("@"):
		var number_str = effect_str.substr(1)
		var delay_value = number_str.to_int()
		effects["char_delay"] = delay_value
	elif effect_str.begins_with("#"):
		var number_str = effect_str.substr(1)
		var speed_value = number_str.to_int()
	elif effect_str.begins_with("$"):
		var number_str = effect_str.substr(1)
		var delay_frames = number_str.to_int()
		effects["delay"] = delay_frames

func delete_rendered():
	for label in text_labels:
		if is_instance_valid(label):
			label.queue_free()
	text_labels.clear()

func delete_banished():
	for label in banished_labels:
		if is_instance_valid(label):
			label.queue_free()
	banished_labels.clear()

func start_next():
	if current_segment_index >= full_dialogue_segments.size():
		print("All dialogue segments completed!")
		return
	if is_typing:
		return
	
	var segment_data = full_dialogue_segments[current_segment_index]
	current_segment_text = segment_data.text
	current_segment_effects = segment_data.effects
	current_position = 0
	current_word_index = 0
	is_typing = true
	waiting_for_input = false
	next_text_position = Vector2.ZERO
	current_ripple_frames = dialogue_data.integers.get("RippleFrames")
	current_char_delay = dialogue_data.integers.get("DelayBetweenCharacters")
	current_word_speed = dialogue_data.integers.get("TextSpeed")
	delete_rendered()
	ripple_positions.clear()
	is_word_mode = (current_char_delay == 0)
	if is_word_mode:
		word_labels()
	else:
		character_labels()
	typing_speed()
	var initial_delay = dialogue_data.integers["Delay"]
	if initial_delay > 0:
		var initial_wait = initial_delay / 60.0
		await get_tree().create_timer(initial_wait).timeout
	typing_timer.start()

func character_labels():
	var x_position = 0.0
	var y_position = 0.0
	var font_size = dialogue_data.integers["FontSize"]
	var line_height = font_size * 1.2
	var char_width = font_size * 0.7
	var space_width = font_size * 0.35
	
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
		char_label.modulate.a = 0.0
		text_container.add_child(char_label)
		text_labels.append(char_label)
		if char == " ":
			x_position += space_width
		else:
			x_position += char_width

func word_labels():
	var x_position = 0.0
	var y_position = 0.0
	var font_size = dialogue_data.integers["FontSize"]
	var line_height = font_size * 1.2
	var char_width = font_size * 0.7 
	var space_width = font_size * 0.35
	var words = []
	var word_char_positions = []
	var current_word = ""
	var current_char_pos = 0
	var word_start_pos = 0
	var i = 0
	
	while i < current_segment_text.length():
		var char = current_segment_text[i]
		
		if char == " ":
			if current_word != "":
				words.append(current_word)
				word_char_positions.append(word_start_pos)
				current_word = ""
			words.append(" ")
			word_char_positions.append(i)
			word_start_pos = i + 1
		elif char == "\n":
			if current_word != "":
				words.append(current_word)
				word_char_positions.append(word_start_pos)
				current_word = ""
			words.append("\n")
			word_char_positions.append(i)
			word_start_pos = i + 1
		else:
			if current_word == "":
				word_start_pos = i
			current_word += char
		
		i += 1
	if current_word != "":
		words.append(current_word)
		word_char_positions.append(word_start_pos)
	current_segment_word_positions = word_char_positions
	
	for word in words:
		if word == "\n":
			y_position += line_height
			x_position = 0.0
			continue
		
		var word_label = Label.new()
		word_label.text = word
		word_label.add_theme_font_size_override("font_size", font_size)
		word_label.add_theme_color_override("font_color", dialogue_data.get_color("Text"))
		
		var outline_size = dialogue_data.integers["OutlineSize"]
		if outline_size > 0:
			word_label.add_theme_constant_override("outline_size", outline_size)
			word_label.add_theme_color_override("font_outline_color", dialogue_data.get_color("Outline"))
		
		word_label.position = Vector2(x_position, y_position)
		word_label.modulate.a = 0.0  # Start invisible
		text_container.add_child(word_label)
		text_labels.append(word_label)
		
		if word == " ":
			x_position += space_width
		else:
			var word_width = word.length() * char_width
			x_position += word_width

func typing_speed():
	var effective_char_delay = current_char_delay if current_char_delay > 0 else dialogue_data.integers["DelayBetweenCharacters"]
	var effective_word_speed = current_word_speed if current_word_speed > 0 else dialogue_data.integers["TextSpeed"]
	
	if effective_char_delay > 0:
		typing_timer.wait_time = effective_char_delay / 60.0
	else:
		typing_timer.wait_time = (60.0 / effective_word_speed)
		word_array()

func word_array():
	words_array = []
	var words = current_segment_text.split(" ")
	for i in range(words.size()):
		words_array.append(words[i])
		if i < words.size() - 1:
			words_array.append(" ")

func effects_apply_wm():
	if current_word_index >= current_segment_word_positions.size():
		return
	
	var word_char_position = current_segment_word_positions[current_word_index]
	var effect_applied = false
	
	for effect_change in current_segment_effects:
		if effect_change.position == word_char_position:
			var old_ripple = current_ripple_frames
			var old_char_delay = current_char_delay
			var old_word_speed = current_word_speed
			current_ripple_frames = effect_change.effects.get("ripple", dialogue_data.integers.get("RippleFrames"))
			current_char_delay = effect_change.effects.get("char_delay", dialogue_data.integers.get("DelayBetweenCharacters"))
			current_word_speed = effect_change.effects.get("word_speed", dialogue_data.integers.get("TextSpeed"))
			var old_mode = is_word_mode
			var new_mode = (current_char_delay == 0)
			var delay_frames = effect_change.effects.get("delay")
			
			if old_mode != new_mode:
				wm_switch(new_mode, word_char_position)
				return
			
			if delay_frames > 0:
				var delay_seconds = delay_frames / 60.0
				typing_timer.stop()
				call_deferred("delay", delay_seconds)
				return
			
			if old_char_delay != current_char_delay or old_word_speed != current_word_speed:
				typing_speed()
			
			effect_applied = true
			break

func wm_switch(new_word_mode: bool, current_char_pos: int):
	typing_timer.stop()
	delete_rendered()
	is_word_mode = new_word_mode
	
	if is_word_mode:
		word_labels()
		current_word_index = 0
		for i in range(current_segment_word_positions.size()):
			if current_segment_word_positions[i] <= current_char_pos:
				current_word_index = i + 1
			else:
				break
		for i in range(min(current_word_index, text_labels.size())):
			text_labels[i].modulate.a = 1.0
	else:
		character_labels()
		current_position = min(current_char_pos, text_labels.size())
		for i in range(current_position):
			text_labels[i].modulate.a = 1.0
	
	typing_speed()
	typing_timer.start()
	
	for effect_change in current_segment_effects:
		if effect_change.position == current_position:
			var old_ripple = current_ripple_frames
			var old_char_delay = current_char_delay
			var old_word_speed = current_word_speed

func update_effects():
	for effect_change in current_segment_effects:
		if effect_change.position == current_position:
			var old_ripple = current_ripple_frames
			var old_char_delay = current_char_delay
			var old_word_speed = current_word_speed
			current_ripple_frames = effect_change.effects.get("ripple", dialogue_data.integers.get("RippleFrames"))
			current_char_delay = effect_change.effects.get("char_delay", dialogue_data.integers.get("DelayBetweenCharacters"))
			current_word_speed = effect_change.effects.get("word_speed", dialogue_data.integers.get("TextSpeed"))
			var old_mode = is_word_mode
			var new_mode = (current_char_delay == 0)
			
			if old_mode != new_mode:
				rendering_switch(new_mode)
				return  
			
			var delay_frames = effect_change.effects.get("delay", 0)
			if delay_frames > 0:
				var delay_seconds = delay_frames / 60.0
				typing_timer.stop()
				call_deferred("delay", delay_seconds)
				return
			
			if old_char_delay != current_char_delay or old_word_speed != current_word_speed:
				typing_speed()
			
			break

func delay(delay_seconds: float):
	await get_tree().create_timer(delay_seconds).timeout
	if is_typing:
		typing_timer.start()

func rendering_switch(new_word_mode: bool):
	typing_timer.stop()
	var chars_consumed = consume()
	calculate_position()
	scale_back()
	
	for label in text_labels:
		if is_instance_valid(label) and label.modulate.a > 0:
			banished_labels.append(label)
	
	text_labels.clear()
	update_unconsumed(chars_consumed)
	is_word_mode = new_word_mode
	
	if current_segment_text.length() > 0:
		if is_word_mode:
			wm_fromswitch()
		else:
			cm_fromswitch()
		
		current_position = 0
		current_word_index = 0
		typing_timer.start()
	else:
		finish_current()
	typing_speed()

func consume() -> int:
	var chars_consumed = 0
	
	if is_word_mode:
		for i in range(current_word_index):
			if i < text_labels.size():
				chars_consumed += text_labels[i].text.length()
	else:
		chars_consumed = current_position
	return chars_consumed

func scale_back():
	for label in text_labels:
		if is_instance_valid(label) and label.modulate.a > 0:
			label.modulate.a = 1.0
			label.scale = Vector2.ONE

func calculate_position():
	var last_visible_label = null
	
	for i in range(text_labels.size() - 1, -1, -1):
		if is_instance_valid(text_labels[i]) and text_labels[i].modulate.a > 0:
			last_visible_label = text_labels[i]
			break
	
	if last_visible_label:
		var font_size = dialogue_data.integers["FontSize"]
		var char_width = font_size * 0.7
		var space_width = font_size * 0.35
		
		if is_word_mode:
			var word_text = last_visible_label.text
			if word_text == " ":
				next_text_position = last_visible_label.position + Vector2(space_width, 0)
			else:
				var word_width = word_text.length() * char_width
				next_text_position = last_visible_label.position + Vector2(word_width, 0)
		else:
			var char_text = last_visible_label.text
			if char_text == " ":
				next_text_position = last_visible_label.position + Vector2(space_width, 0)
			else:
				next_text_position = last_visible_label.position + Vector2(char_width, 0)
	else:
		next_text_position = Vector2.ZERO

func update_unconsumed(chars_consumed: int):
	if chars_consumed < current_segment_text.length():
		current_segment_text = current_segment_text.substr(chars_consumed)
		var new_effects = []
		for effect in current_segment_effects:
			if effect.position >= chars_consumed:
				var new_effect = effect.duplicate()
				new_effect.position -= chars_consumed
				new_effects.append(new_effect)
		current_segment_effects = new_effects
	else:
		current_segment_text = ""
		current_segment_effects = []

func cm_fromswitch():
	var x_position = next_text_position.x
	var y_position = next_text_position.y
	var font_size = dialogue_data.integers["FontSize"]
	var line_height = font_size * 1.2
	var char_width = font_size * 0.7
	var space_width = font_size * 0.35
	
	for i in range(current_segment_text.length()):
		var char = current_segment_text[i]
		
		if char == "\n":
			y_position += line_height
			x_position = next_text_position.x
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
		char_label.modulate.a = 0.0
		text_container.add_child(char_label)
		text_labels.append(char_label)
		
		if char == " ":
			x_position += space_width
		else:
			x_position += char_width

func wm_fromswitch():
	var x_position = next_text_position.x
	var y_position = next_text_position.y
	var font_size = dialogue_data.integers["FontSize"]
	var line_height = font_size * 1.2
	var char_width = font_size * 0.7
	var space_width = font_size * 0.35
	var words = []
	var word_char_positions = []
	var current_word = ""
	var word_start_pos = 0
	
	for i in range(current_segment_text.length()):
		var char = current_segment_text[i]
		
		if char == " ":
			if current_word != "":
				words.append(current_word)
				word_char_positions.append(word_start_pos)
				current_word = ""
			words.append(" ")
			word_char_positions.append(i)
			word_start_pos = i + 1
		elif char == "\n":
			if current_word != "":
				words.append(current_word)
				word_char_positions.append(word_start_pos)
				current_word = ""
			words.append("\n")
			word_char_positions.append(i)
			word_start_pos = i + 1
		else:
			if current_word == "":
				word_start_pos = i
			current_word += char
	
	if current_word != "":
		words.append(current_word)
		word_char_positions.append(word_start_pos)
	
	current_segment_word_positions = word_char_positions
	
	for word in words:
		if word == "\n":
			y_position += line_height
			x_position = next_text_position.x
			continue
		
		var word_label = Label.new()
		word_label.text = word
		word_label.add_theme_font_size_override("font_size", font_size)
		word_label.add_theme_color_override("font_color", dialogue_data.get_color("Text"))
		var outline_size = dialogue_data.integers["OutlineSize"]
		
		if outline_size > 0:
			word_label.add_theme_constant_override("outline_size", outline_size)
			word_label.add_theme_color_override("font_outline_color", dialogue_data.get_color("Outline"))
		
		word_label.position = Vector2(x_position, y_position)
		word_label.modulate.a = 0.0
		text_container.add_child(word_label)
		text_labels.append(word_label)
		
		if word == " ":
			x_position += space_width
		else:
			var word_width = word.length() * char_width
			x_position += word_width

func _render_timer():
	var effective_char_delay = current_char_delay if current_char_delay > 0 else dialogue_data.integers["DelayBetweenCharacters"]
	
	if effective_char_delay > 0 or not is_word_mode:
		if current_position < text_labels.size():
			update_effects()
			var char_label = text_labels[current_position]
			var char = current_segment_text[current_position]
			char_label.modulate.a = 1.0
			
			if char != " " and current_ripple_frames > 0:
				ripple(current_position, current_ripple_frames)
			
			current_position += 1
			
			while current_position < current_segment_text.length() and current_segment_text[current_position] == " ":
				update_effects()
				if current_position < text_labels.size():
					text_labels[current_position].modulate.a = 1.0
				current_position += 1
		
		if current_position >= text_labels.size():
			finish_current()
	else:
		if current_word_index < text_labels.size():
			effects_apply_wm()
			var word_label = text_labels[current_word_index]
			var word_text = word_label.text
			word_label.modulate.a = 1.0
			if current_ripple_frames > 0 and word_text != " " and word_text != "\n":
				ripple(current_word_index, current_ripple_frames)
			
			current_word_index += 1
		else:
			finish_current()

func ripple(position: int, ripple_frames: int):
	var ripple_data = {
		"center": position,
		"start_time": Time.get_ticks_msec(),
		"duration": ripple_frames * (1000.0 / 60.0)
	}
	ripple_positions.append(ripple_data)

func _ripple_timer():
	var current_time = Time.get_ticks_msec()
	ripple_positions = ripple_positions.filter(func(ripple): 
		return (current_time - ripple.start_time) < ripple.duration)
	
	if ripple_positions.size() > 0:
		ripple_effect()

func ripple_effect():
	for i in range(text_labels.size()):
		if i < text_labels.size() and is_instance_valid(text_labels[i]):
			var label = text_labels[i]
			var scale_multiplier = 1.0
			
			for ripple_data in ripple_positions:
				var distance = abs(i - ripple_data.center)
				var time_elapsed = Time.get_ticks_msec() - ripple_data.start_time
				
				if time_elapsed < ripple_data.duration:
					var time_factor = 1.0 - (time_elapsed / ripple_data.duration)
					var distance_factor = max(0.0, 1.0 - (distance / 3.0))
					var ripple_strength = time_factor * distance_factor * 0.4
					scale_multiplier += ripple_strength
			
			label.scale = Vector2(scale_multiplier, scale_multiplier)

func finish_current():
	is_typing = false
	typing_timer.stop()
	scale_back()
	var max_ripple_duration = 0.0
	ripple_positions.clear()
	
	for label in text_labels:
		if is_instance_valid(label):
			label.modulate.a = 1.0
			label.scale = Vector2.ONE
	
	for ripple in ripple_positions:
		var remaining_time = (ripple.duration - (Time.get_ticks_msec() - ripple.start_time)) / 1000.0
		max_ripple_duration = max(max_ripple_duration, remaining_time)
	
	if max_ripple_duration > 0:
		await get_tree().create_timer(max_ripple_duration).timeout
	
	for label in text_labels:
		if is_instance_valid(label):
			label.scale = Vector2.ONE
	
	for label in banished_labels:
		if is_instance_valid(label):
			label.scale = Vector2.ONE
	
	waiting_for_input = true

func next():
	if not waiting_for_input:
		return
	
	if text_container:
		for i in range(text_container.get_child_count()):
			var child = text_container.get_child(i)
	
	for label in banished_labels:
		if is_instance_valid(label):
			label.get_parent().remove_child(label)
			label.queue_free()
	banished_labels.clear()
	
	for label in text_labels:
		if is_instance_valid(label):
			label.get_parent().remove_child(label)
			label.queue_free()
	text_labels.clear()
	
	if text_container:
		var children_to_remove = text_container.get_children()
		for child in children_to_remove:
			if is_instance_valid(child):
				text_container.remove_child(child)
				child.queue_free()
	
	current_segment_index += 1
	start_next()

func skip():
	if is_typing:
		finish_current()

func _button():
	if is_typing:
		skip()
	elif waiting_for_input:
		next()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if is_typing:
			skip()
		elif waiting_for_input:
			next()
