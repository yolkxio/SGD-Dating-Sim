extends Control

@export var dialogue_data: DialogueData
@export var character_data: CharacterData
@export var name_tag: NameTag

var choice_mode: bool = false
var choice_options: Array = []
var choice_destinations: Array = []
var choice_buttons: Array = []
var choice_container: Control
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
var choice_vbox: VBoxContainer
var audio_player: AudioStreamPlayer
var current_character_image_key: String = ""
var entrance_completed: bool = false
var is_entrance_playing: bool = false
var processed_entrance_positions: Array = []
var is_word_mode: bool = false
var current_segment_word_positions: Array = []
var next_text_position: Vector2 = Vector2.ZERO
var current_ripple_frames: int = 0
var current_char_delay: int = 0
var current_word_speed: int = 0
var in_effect_zone: bool = false
var current_effect_zone: Dictionary = {}
var ripple_timer: Timer
var ripple_positions: Array = []
var shake_effects: Array = []
var effect_update_timer: Timer
var jitter_effects: Array = []
var wiggle_effects: Array = []
var icon_button: TextureButton
var super_pause_active: bool = false
var super_pause_word_count: int = 0
var waiting_for_super_pause_input: bool = false

func _ready():
	setup_choice()
	setup_audio()
	typing_system()
	dialogue_box()
	connect_button()
	setup_name_tag()

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
	
	effect_update_timer = Timer.new()
	add_child(effect_update_timer)
	effect_update_timer.timeout.connect(_update_effects)
	effect_update_timer.wait_time = 0.016
	effect_update_timer.start()

func dialogue_box():
	text_container = $TextContainer/TextBackground/MarginContainer/TextContainer
	load_text()

func connect_button():
	icon_button = $TextContainer/TextureButton
	if icon_button:
		icon_button.pressed.connect(_button)

func setup_audio():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

func setup_choice():
	choice_container = $TextContainer/TextBackground/MarginContainer/ChoiceContainer
	if choice_container:
		choice_container.visible = false
		choice_vbox = $TextContainer/TextBackground/MarginContainer/ChoiceContainer/VBoxContainer

func set_character(character: CharacterData):
	character_data = character
	
	# Update the name tag when character changes
	if name_tag:
		name_tag.set_character(character_data)

func setup_name_tag():
	if not name_tag:
		name_tag = $NameTag as NameTag  # Fallback path
	
	if name_tag and character_data:
		name_tag.set_character(character_data)

func load_text():
	var file_path = dialogue_data.text_file_path
	var file_content = ""
	
	if FileAccess.file_exists(file_path):
		var file = FileAccess.open(file_path, FileAccess.READ)
		file_content = file.get_as_text()
		file.close()
	
	parse_text(file_content)
	
	if not choice_mode and full_dialogue_segments.size() > 0:
		start_next()

func parse_text(content: String):
	full_dialogue_segments.clear()
	current_segment_index = 0
	var raw_segments = content.split("<>")
	@warning_ignore("unused_variable")
	var choice_sequence_detected = false
	var i = 0
	
	while i < raw_segments.size():
		var current_segment = raw_segments[i].strip_edges()
		
		if current_segment.contains("[:]"):
			choice_sequence_detected = true
			
			if current_segment.length() > 0:
				var parsed_data = find_effects(current_segment)
				parsed_data["is_choice_prompt"] = true
				full_dialogue_segments.append(parsed_data)
			
			var choice_options_text = []
			var j = i + 1
			while j < raw_segments.size():
				var choice_segment = raw_segments[j].strip_edges()
				if choice_segment.length() > 0 and choice_segment.contains("[:"):
					choice_options_text.append(choice_segment)
				else:
					if choice_segment.length() > 0:
						var regular_data = find_effects(choice_segment)
						full_dialogue_segments.append(regular_data)
					j += 1
					continue
				j += 1
			
			var choice_data = create_choice_data(choice_options_text)
			full_dialogue_segments.append(choice_data)
			i = j
			continue
		else:
			if current_segment.length() > 0:
				var parsed_data = find_effects(current_segment)
				full_dialogue_segments.append(parsed_data)
		
		i += 1

func create_choice_data(choice_options_text: Array) -> Dictionary:
	choice_options.clear()
	choice_destinations.clear()
	
	for choice_text in choice_options_text:
		var trimmed_choice = choice_text.strip_edges()
		if trimmed_choice.length() > 0:
			var destination_index = -1
			var clean_choice_text = trimmed_choice
			var regex = RegEx.new()
			regex.compile("\\[:(\\d+)\\]")
			var result = regex.search(trimmed_choice)
			
			if result:
				destination_index = result.get_string(1).to_int()
				clean_choice_text = trimmed_choice.replace(result.get_string(0), "").strip_edges()
			
			if clean_choice_text.length() > 0:
				choice_options.append(clean_choice_text)
				choice_destinations.append(destination_index)
	
	return {
		"text": "",
		"effects": [],
		"is_choice": true
	}

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
				
				if effect_content.ends_with("{"):
					var effect_str = effect_content.substr(0, effect_content.length() - 1)
					var new_effects = parse_effects(effect_str)
					effects_data.append({
						"position": clean_text.length(),
						"effects": new_effects,
						"type": "start_zone"
					})
				elif effect_content == "}":
					effects_data.append({
						"position": clean_text.length(),
						"effects": {},
						"type": "end_zone"
					})
				else:
					var new_effects = parse_effects(effect_content)
					effects_data.append({
						"position": clean_text.length(),
						"effects": new_effects,
						"type": "permanent"
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
		"delay": 0,
		"jitter": 0,
		"shake": 0,
		"wiggle": 0,
		"change_image": "",
		"super_pause": false
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
		effects["word_speed"] = speed_value
	elif effect_str.begins_with("$"):
		var number_str = effect_str.substr(1)
		var delay_frames = number_str.to_int()
		effects["delay"] = delay_frames
	elif effect_str.begins_with("%"):
		var number_str = effect_str.substr(1)
		var jitter_intensity = number_str.to_int() if number_str != "" else 2
		effects["jitter"] = jitter_intensity
	elif effect_str.begins_with("^"):
		var number_str = effect_str.substr(1)
		var shake_frames = number_str.to_int()
		effects["shake"] = shake_frames
	elif effect_str.begins_with("&"):
		var number_str = effect_str.substr(1)
		var wiggle_intensity = number_str.to_int() if number_str != "" else 5
		effects["wiggle"] = wiggle_intensity
	elif effect_str.begins_with("*") and effect_str.length() == 1:
		effects["super_pause"] = true
	elif effect_str.begins_with("a'") and effect_str.ends_with("'"):
		var image_key = effect_str.substr(2, effect_str.length() - 3)
		effects["change_image"] = image_key
	elif effect_str.begins_with("<'") and effect_str.ends_with("'"):
		var sound_key = effect_str.substr(2, effect_str.length() - 3)
		effects["play_sound"] = sound_key
	elif effect_str.begins_with(">'") and effect_str.ends_with("'"):
		var popup_image_key = effect_str.substr(2, effect_str.length() - 3)
		effects["popup_image"] = popup_image_key

func play_sound():
	if character_data and audio_player:
		var talking_sound = character_data.character_sounds.get("talking")
		if talking_sound:
			audio_player.stream = talking_sound
			audio_player.pitch_scale = randf_range(0.9, 1.1)
			audio_player.play()

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
	if is_typing or is_entrance_playing:
		return
	if current_segment_index == 0:
		entrance_completed = false
	
	var segment_data = full_dialogue_segments[current_segment_index]
	
	if segment_data.get("is_choice", false):
		choice_mode = true
		display_choices()
		return
	
	current_segment_text = segment_data.text
	current_segment_effects = segment_data.effects
	current_position = 0
	current_word_index = 0
	is_typing = true
	waiting_for_input = false
	waiting_for_super_pause_input = false
	super_pause_active = false
	super_pause_word_count = 0
	next_text_position = Vector2.ZERO
	current_ripple_frames = dialogue_data.integers.get("RippleFrames")
	current_char_delay = dialogue_data.integers.get("DelayBetweenCharacters")
	current_word_speed = dialogue_data.integers.get("TextSpeed")
	delete_rendered()
	is_word_mode = (current_char_delay == 0)
	in_effect_zone = false
	current_effect_zone.clear()
	ripple_positions.clear()
	jitter_effects.clear()
	wiggle_effects.clear()
	shake_effects.clear()
	processed_entrance_positions.clear()
	await handle_entrance_if_needed()
	
	if entrance_completed:
		update_character_talking_state()
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

func get_word_width(word: String, font_size: int) -> float:
	var temp_label = Label.new()
	temp_label.add_theme_font_size_override("font_size", font_size)
	temp_label.text = word
	add_child(temp_label)
	
	temp_label.force_update_transform()
	var word_size = temp_label.get_theme_font("font").get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	
	remove_child(temp_label)
	temp_label.queue_free()
	return word_size.x

func character_labels():
	var x_position = 0.0
	var y_position = 0.0
	var font_size = dialogue_data.integers["FontSize"]
	var line_height = font_size * 1.2
	
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
		
		var actual_width = get_char_width(char, font_size)
		x_position += actual_width

func word_labels():
	var x_position = 0.0
	var y_position = 0.0
	var font_size = dialogue_data.integers["FontSize"]
	var line_height = font_size * 1.2
	var words = []
	var word_char_positions = []
	var current_word = ""
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
	
	for j in range(words.size()):
		var word = words[j]
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
		word_label.modulate.a = 0.0
		text_container.add_child(word_label)
		text_labels.append(word_label)
		
		var actual_width = get_word_width(word, font_size)
		x_position += actual_width

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
	# Safety checks
	if current_segment_word_positions.is_empty():
		print("Warning: No word positions available")
		return
		
	if current_word_index >= current_segment_word_positions.size():
		return
	
	var word_char_position = current_segment_word_positions[current_word_index]
	
	for effect_change in current_segment_effects:
		if effect_change.position == word_char_position:
			var effect_type = effect_change.get("type", "permanent")
			
			if effect_type == "start_zone":
				in_effect_zone = true
				current_effect_zone = effect_change.effects.duplicate()
				current_char_delay = current_effect_zone.get("char_delay", current_char_delay)
				current_word_speed = current_effect_zone.get("word_speed", current_word_speed)
			elif effect_type == "end_zone":
				in_effect_zone = false
				current_effect_zone.clear()
			else:
				current_char_delay = effect_change.effects.get("char_delay", current_char_delay)
				current_word_speed = effect_change.effects.get("word_speed", current_word_speed)
			
			var old_mode = is_word_mode
			var new_mode = (current_char_delay == 0)
			
			if old_mode != new_mode:
				wm_switch(new_mode, word_char_position)
				return
			
			var delay_frames = effect_change.effects.get("delay")
			if delay_frames != null and delay_frames > 0:
				var delay_seconds = delay_frames / 60.0
				typing_timer.stop()
				call_deferred("delay", delay_seconds)
				return
			
			typing_speed()

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
			@warning_ignore("unused_variable")
			var old_ripple = current_ripple_frames
			@warning_ignore("unused_variable")
			var old_char_delay = current_char_delay
			@warning_ignore("unused_variable")
			var old_word_speed = current_word_speed

func update_effects():
	for effect_change in current_segment_effects:
		if effect_change.position == current_position:
			var effect_type = effect_change.get("type", "permanent")
			
			if effect_type == "start_zone":
				in_effect_zone = true
				current_effect_zone = effect_change.effects.duplicate()
				current_ripple_frames = current_effect_zone.get("ripple", dialogue_data.integers.get("RippleFrames"))
				current_char_delay = current_effect_zone.get("char_delay", dialogue_data.integers.get("DelayBetweenCharacters"))
				current_word_speed = current_effect_zone.get("word_speed", dialogue_data.integers.get("TextSpeed"))
			elif effect_type == "end_zone":
				in_effect_zone = false
				current_effect_zone.clear()
				ripple_positions.clear()
				for label in text_labels:
					if is_instance_valid(label):
						label.scale = Vector2.ONE
			else:
				@warning_ignore("unused_variable")
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
		var actual_width = get_word_width(last_visible_label.text, font_size)
		next_text_position = last_visible_label.position + Vector2(actual_width, 0)
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
		
		var actual_width = get_char_width(char, font_size)
		x_position += actual_width

func wm_fromswitch():
	var x_position = next_text_position.x
	var y_position = next_text_position.y
	var font_size = dialogue_data.integers["FontSize"]
	var line_height = font_size * 1.2
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
		
		var actual_width = get_word_width(word, font_size)
		x_position += actual_width

func _render_timer():
	if is_entrance_playing:
		return
	
	var effective_char_delay = current_char_delay if current_char_delay > 0 else dialogue_data.integers["DelayBetweenCharacters"]
	
	if effective_char_delay > 0 or not is_word_mode:
		# Character mode rendering
		if current_position < text_labels.size() and current_position < current_segment_text.length():
			update_effects()
			var char_label = text_labels[current_position]
			var char = current_segment_text[current_position]
			char_label.modulate.a = 1.0
			apply_effects_to_current_position(current_position)
			
			if char != " " and char != "\n":
				play_sound()
			
			current_position += 1
			
			while current_position < current_segment_text.length() and current_segment_text[current_position] == " ":
				update_effects()
				if current_position < text_labels.size():
					var space_label = text_labels[current_position]
					space_label.modulate.a = 1.0
					apply_effects_to_current_position(current_position)
				current_position += 1
		
		if current_position >= text_labels.size() or current_position >= current_segment_text.length():
			finish_current()
	else:
		# Word mode rendering
		if current_word_index < text_labels.size():
			effects_apply_wm()
			var word_label = text_labels[current_word_index]
			var word_text = word_label.text
			word_label.modulate.a = 1.0
			apply_effects_to_current_position(current_word_index)
			
			if word_text != " " and word_text != "\n":
				play_sound()
			
			current_word_index += 1
			
			var word_char_position = current_segment_word_positions[current_word_index - 1] if (current_word_index - 1) < current_segment_word_positions.size() else -1
			for effect_change in current_segment_effects:
				if effect_change.position == word_char_position and effect_change.effects.get("super_pause", false):
					super_pause_active = true
					super_pause_word_count = 0
					break
					
			if super_pause_active:
				super_pause_word_count += 1
				if super_pause_word_count >= 1:
					waiting_for_super_pause_input = true
					typing_timer.stop()
					update_character_talking_state()
					return
		else:
			finish_current()

func apply_effects_to_current_position(position: int):
	var text_pos = position
	if is_word_mode and position < current_segment_word_positions.size():
		text_pos = current_segment_word_positions[position]
	
	for effect_change in current_segment_effects:
		if effect_change.position == text_pos:
			var image_key = effect_change.effects.get("change_image", "")
			if image_key != "":
				if image_key == "entrance" and effect_change.position in processed_entrance_positions:
					continue
				change_character_image(image_key)
			var sound_key = effect_change.effects.get("play_sound", "")
			if sound_key != "":
				play_effect_sound(sound_key)
			var popup_key = effect_change.effects.get("popup_image", "")
			if popup_key != "":
				show_popup_image(popup_key)
	
	var current_ripple_value = 0
	for effect_change in current_segment_effects:
		if effect_change.position <= text_pos:
			if effect_change.get("type") == "start_zone":
				current_ripple_value = effect_change.effects.get("ripple", 0)
			elif effect_change.get("type") == "end_zone":
				current_ripple_value = 0
			elif effect_change.get("type") == "permanent":
				current_ripple_value = effect_change.effects.get("ripple", 0)
	
	if current_ripple_value > 0 and position < text_labels.size():
		ripple_targeted(text_labels[position], current_ripple_value)
	
	var in_zone = false
	var zone_jitter = 0
	var zone_wiggle = 0
	var zone_shake = 0
	
	for effect_change in current_segment_effects:
		if effect_change.position <= text_pos:
			if effect_change.get("type") == "start_zone":
				in_zone = true
				zone_jitter = effect_change.effects.get("jitter", 0)
				zone_wiggle = effect_change.effects.get("wiggle", 0)
				zone_shake = effect_change.effects.get("shake", 0)
			elif effect_change.get("type") == "end_zone":
				in_zone = false
	if in_zone:
		if zone_jitter > 0:
			apply_jitter_to_position(position, zone_jitter)
		
		if zone_wiggle > 0:
			apply_wiggle_to_position(position, zone_wiggle)
		
		if zone_shake > 0:
			apply_shake_to_position(position, zone_shake)

func ripple_targeted(label: Label, ripple_frames: int):
	var ripple_data = {
		"label": label,
		"start_time": Time.get_ticks_msec(),
		"duration": ripple_frames * (1000.0 / 60.0)
	}
	ripple_positions.append(ripple_data)

func _ripple_timer():
	var current_time = Time.get_ticks_msec()
	ripple_positions = ripple_positions.filter(func(ripple): 
		return (current_time - ripple.start_time) < ripple.duration and is_instance_valid(ripple.label))
	
	if ripple_positions.size() > 0:
		ripple_effect_targeted()

func ripple_effect_targeted():
	for label in text_labels:
		if is_instance_valid(label):
			label.scale = Vector2.ONE
	
	for ripple_data in ripple_positions:
		if is_instance_valid(ripple_data.label):
			var time_elapsed = Time.get_ticks_msec() - ripple_data.start_time
			
			if time_elapsed < ripple_data.duration:
				var time_factor = 1.0 - (time_elapsed / ripple_data.duration)
				var ripple_strength = time_factor * 0.4
				var scale_multiplier = 1.0 + ripple_strength
				ripple_data.label.scale = Vector2(scale_multiplier, scale_multiplier)

func apply_jitter_to_position(position: int, intensity: int):
	if position < text_labels.size() and is_instance_valid(text_labels[position]):
		var jitter_data = {
			"label": text_labels[position],
			"intensity": intensity,
			"active": true
		}
		jitter_effects.append(jitter_data)

func apply_shake_to_position(position: int, frames: int, intensity: int = 3):
	if position < text_labels.size() and is_instance_valid(text_labels[position]):
		var shake_data = {
			"label": text_labels[position],
			"start_time": Time.get_ticks_msec(),
			"duration": frames * (1000.0 / 60.0),
			"intensity": intensity,
			"original_pos": text_labels[position].position
		}
		shake_effects.append(shake_data)

func apply_wiggle_to_position(position: int, intensity: int):
	if position < text_labels.size() and is_instance_valid(text_labels[position]):
		var wiggle_data = {
			"label": text_labels[position],
			"intensity": intensity,
			"active": true
		}
		wiggle_effects.append(wiggle_data)

func change_character_image(image_key: String):
	if character_data:
		if image_key == "entrance":
			if not entrance_completed:
				var entrance_texture = character_data.character_images.get("entrance")
				if entrance_texture:
					await handle_entrance_fade(entrance_texture)
					entrance_completed = true 
			return
		var character_image_array = character_data.character_images.get(image_key)
		if character_image_array and character_image_array is Array and character_image_array.size() >= 2:
			current_character_image_key = image_key
			if entrance_completed:
				update_character_talking_state()

func play_effect_sound(sound_key: String):
	if character_data and character_data.character_sounds.has(sound_key):
		var sound_stream = character_data.character_sounds.get(sound_key)
		if sound_stream:
			var effect_audio_player = AudioStreamPlayer.new()
			add_child(effect_audio_player)
			effect_audio_player.stream = sound_stream
			effect_audio_player.play()
			effect_audio_player.finished.connect(func(): 
				effect_audio_player.queue_free()
			)

func show_popup_image(image_key: String):
	if character_data and character_data.character_images.has(image_key):
		var popup_texture = character_data.character_images.get(image_key)
		if popup_texture:
			var popup_image = TextureRect.new()
			popup_image.texture = popup_texture
			popup_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			popup_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var screen_size = get_viewport().get_visible_rect().size
			var image_size = popup_texture.get_size()
			var scale_factor = min(screen_size.x / image_size.x, screen_size.y / image_size.y) * 0.8  
			popup_image.custom_minimum_size = image_size * scale_factor
			popup_image.size = image_size * scale_factor
			popup_image.position = (screen_size - popup_image.size) / 2
			popup_image.scale = Vector2(0.1, 0.1)
			popup_image.modulate.a = 0.0
			popup_image.pivot_offset = popup_image.size / 2
			get_tree().current_scene.add_child(popup_image)
			_animate_popup(popup_image)

func _animate_popup(popup_image: TextureRect):
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup_image, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(popup_image, "modulate:a", 1.0, 0.2)
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(popup_image):
		var fade_tween = get_tree().create_tween()
		fade_tween.tween_property(popup_image, "modulate:a", 0.0, 0.4)
		fade_tween.finished.connect(func(): 
			if is_instance_valid(popup_image):
				popup_image.queue_free()
		)

func handle_entrance_fade(entrance_texture: Texture2D):
	is_entrance_playing = true
	
	var character_rect = $Character
	if character_rect and character_rect is TextureRect:
		character_rect.texture = entrance_texture
		character_rect.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(character_rect, "modulate:a", 1.0, 1)
		await tween.finished
	
	is_entrance_playing = false
	entrance_completed = true

func handle_entrance_if_needed():
	var entrance_found = false
	
	for effect_change in current_segment_effects:
		if effect_change.position == 0:
			var image_key = effect_change.effects.get("change_image", "")
			if image_key == "entrance":
				entrance_found = true
				var entrance_texture = character_data.character_images.get("entrance")
				if entrance_texture:
					await handle_entrance_fade(entrance_texture)
					processed_entrance_positions.append(0)
				return
	
	if not entrance_found:
		entrance_completed = true

func update_character_talking_state():
	if is_entrance_playing or not entrance_completed:
		return
		
	if current_character_image_key == "" or not character_data:
		return
		
	var character_image_array = character_data.character_images.get(current_character_image_key)
	if character_image_array and character_image_array is Array and character_image_array.size() >= 2:
		var character_rect = $Character
		if character_rect and character_rect is TextureRect:
			if waiting_for_input:
				character_rect.texture = character_image_array[0]
			else:
				character_rect.texture = character_image_array[1]

func _update_effects():
	var current_time = Time.get_ticks_msec()
	
	for jitter_data in jitter_effects:
		if is_instance_valid(jitter_data.label) and jitter_data.active:
			var jitter_offset = Vector2(
				randf_range(-jitter_data.intensity, jitter_data.intensity),
				randf_range(-jitter_data.intensity, jitter_data.intensity)
			)
			if not jitter_data.label.has_meta("original_pos"):
				jitter_data.label.set_meta("original_pos", jitter_data.label.position)
			
			var original_pos = jitter_data.label.get_meta("original_pos")
			jitter_data.label.position = original_pos + jitter_offset
	
	shake_effects = shake_effects.filter(func(shake):
		if not is_instance_valid(shake.label):
			return false
		
		var elapsed = current_time - shake.start_time
		if elapsed < shake.duration:
			var shake_factor = 1.0 - (elapsed / shake.duration)
			var shake_offset = Vector2(
				randf_range(-shake.intensity * shake_factor, shake.intensity * shake_factor),
				randf_range(-shake.intensity * shake_factor, shake.intensity * shake_factor)
			)
			shake.label.position = shake.original_pos + shake_offset
			return true
		else:
			shake.label.position = shake.original_pos
			return false
	)
	
	for wiggle_data in wiggle_effects:
		if is_instance_valid(wiggle_data.label) and wiggle_data.active:
			var wiggle_rotation = sin(current_time * 0.01) * deg_to_rad(wiggle_data.intensity)
			wiggle_data.label.rotation = wiggle_rotation

func display_choices():
	clear_choice_buttons()
	show_choice_container()
	create_choice_buttons()
	waiting_for_input = true
	update_character_talking_state()

func show_choice_container():
	choice_container.visible = true
	var choice_count = choice_options.size()
	
	if choice_container is Control:
		var base_height = 100 
		var height_per_choice = 60 
		var total_height = base_height + (choice_count * height_per_choice)
		
		choice_container.size.y = total_height

func create_choice_buttons():
	for i in range(choice_options.size()):
		var button = Button.new()
		button.text = choice_options[i]
		button.add_theme_font_size_override("font_size", dialogue_data.integers["FontSize"])
		var choice_index = i
		button.pressed.connect(func(): select_choice(choice_index))
		choice_vbox.add_child(button)
		choice_buttons.append(button)

func select_choice(choice_index: int):
	if choice_index >= 0 and choice_index < choice_destinations.size():
		var destination = choice_destinations[choice_index]
		
		if destination >= 0 and character_data != null:
			if destination < character_data.dialogue_text_files.size():
				var new_file_path = character_data.dialogue_text_files[destination]
				dialogue_data.text_file_path = new_file_path
				hide_choice_container()
				choice_mode = false
				load_text()

func hide_choice_container():
	choice_container.visible = false
	clear_choice_buttons()

func clear_choice_buttons():
	for button in choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	choice_buttons.clear()

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
	
	if current_segment_index < full_dialogue_segments.size():
		var current_segment = full_dialogue_segments[current_segment_index]
		if current_segment.get("is_choice_prompt", false):
			current_segment_index += 1
			start_next()
			return
	
	waiting_for_input = true
	update_character_talking_state()

func next():
	if not waiting_for_input:
		return
	
	if text_container:
		for i in range(text_container.get_child_count()):
			@warning_ignore("unused_variable")
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
	if choice_mode:
		return
	elif waiting_for_super_pause_input:
		waiting_for_super_pause_input = false
		super_pause_active = false
		super_pause_word_count = 0
		update_character_talking_state()
		typing_timer.start()
	elif is_typing:
		skip()
	elif waiting_for_input:
		next()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		if choice_mode:
			return
		elif waiting_for_super_pause_input:
			waiting_for_super_pause_input = false
			super_pause_active = false
			super_pause_word_count = 0
			update_character_talking_state()
			typing_timer.start()
		elif is_typing:
			skip()
		elif waiting_for_input:
			next()
