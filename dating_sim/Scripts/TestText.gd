extends Control

@export var dialogue_data: DialogueData
@export var character_data: CharacterData
@export var name_tag: NameTag

var effects_manager: EffectManager
var character_manager: CharacterManager
var text_manager: TextManager
var render_segments: Array = []
var current_render_index: int = 0
var typing_timer: Timer
var choice_mode: bool = false
var choice_options: Array = []
var choice_destinations: Array = []
var choice_buttons: Array = []
var choice_container: Control
var full_dialogue_segments: Array = []
var current_segment_index: int = 0
var current_segment_text: String = ""
var current_segment_effects: Array = []
var is_typing: bool = false
var is_switching_modes: bool = false
var current_position: int = 0
var current_word_index: int = 0
var waiting_for_input: bool = false
var text_container: Control
var choice_vbox: VBoxContainer
var current_char_delay: int = 0
var current_word_speed: int = 0
var icon_button: TextureButton
var super_pause_active: bool = false
var waiting_for_super_pause_input: bool = false
var fps: float = 60.0

class RenderSegment:
	var text: String
	var start_pos: int
	var end_pos: int
	var is_word_mode: bool
	var char_delay: int
	var word_speed: int
	var effects: Dictionary
	
	func _init(txt: String, start: int, end: int, word_mode: bool, delay: int, speed: int, fx: Dictionary):
		text = txt
		start_pos = start
		end_pos = end
		is_word_mode = word_mode
		char_delay = delay
		word_speed = speed
		effects = fx

func _ready():
	fps = dialogue_data.get_float("FramesPerSecond", 60.0)
	
	# Initialize managers
	effects_manager = EffectManager.new()
	add_child(effects_manager)
	effects_manager.initialize(dialogue_data)
	
	text_manager = TextManager.new()
	add_child(text_manager)
	text_manager.initialize(dialogue_data, $TextContainer/TextBackground/MarginContainer/TextContainer)
	
	character_manager = CharacterManager.new()
	add_child(character_manager)
	character_manager.initialize(dialogue_data, character_data, name_tag, $Character)
	
	# Connect signals
	effects_manager.effect_sound_requested.connect(character_manager.play_effect_sound)
	effects_manager.character_image_change_requested.connect(character_manager.change_character_image)
	effects_manager.popup_image_requested.connect(character_manager.show_popup_image)
	character_manager.entrance_completed.connect(_on_entrance_completed)
	
	setup_choice()
	typing_system()
	dialogue_box()
	connect_button()

func typing_system():
	typing_timer = Timer.new()
	add_child(typing_timer)
	typing_timer.timeout.connect(_render_timer)
	typing_timer.wait_time = dialogue_data.get_float("TypingTimerInterval", 0.1)

func dialogue_box():
	text_container = $TextContainer/TextBackground/MarginContainer/TextContainer
	load_text()

func connect_button():
	icon_button = $TextContainer/TextureButton
	if icon_button:
		icon_button.pressed.connect(_button)

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
	
	print("Raw segments found: ", raw_segments.size())
	
	var i = 0
	while i < raw_segments.size():
		var current_segment = raw_segments[i].strip_edges()
		
		# Skip empty segments
		if current_segment.length() == 0:
			i += 1
			continue
		
		if current_segment.contains("[:]"):
			# Handle choice sequence
			if current_segment.length() > 0:
				var parsed_data = effects_manager.find_effects(current_segment)
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
						var regular_data = effects_manager.find_effects(choice_segment)
						full_dialogue_segments.append(regular_data)
					break
				j += 1
			
			var choice_data = create_choice_data(choice_options_text)
			full_dialogue_segments.append(choice_data)
			i = j  # Skip to after the choices
		else:
			# Regular dialogue segment
			var parsed_data = effects_manager.find_effects(current_segment)
			full_dialogue_segments.append(parsed_data)
			i += 1
	
	print("Final parsed segments: ", full_dialogue_segments.size())

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

func start_next():
	print("=== START_NEXT CALLED ===")
	
	if current_segment_index >= full_dialogue_segments.size():
		return
	
	var segment_data = full_dialogue_segments[current_segment_index]
	
	if segment_data.get("is_choice", false):
		choice_mode = true
		display_choices()
		return
	
	current_segment_text = segment_data.text
	current_segment_effects = segment_data.effects
	
	# Reset state
	is_typing = true
	waiting_for_input = false
	
	# PRE-PROCESS: Split text into render segments based on effects
	split_into_render_segments()
	print("Split complete, segments: ", render_segments.size())
	
	# Initialize text manager
	text_manager.prepare_segment(current_segment_text, current_segment_effects)
	effects_manager.set_text_labels(text_manager.get_text_labels())
	effects_manager.clear_effects()
	
	# Handle entrance
	await character_manager.handle_entrance_if_needed(current_segment_effects)
	
	if character_manager.is_entrance_done():
		character_manager.update_character_talking_state(false)
	
	# Start rendering first segment
	current_render_index = 0
	render_next_segment()

func split_into_render_segments():
	render_segments.clear()
	
	var segments = []
	var current_pos = 0
	var current_char_delay = dialogue_data.integers["DelayBetweenCharacters"]
	var current_word_speed = dialogue_data.integers["TextSpeed"]
	var in_zone = false
	var zone_effects = {}
	
	# Find all effect positions and create segments
	var effect_positions = []
	for effect in current_segment_effects:
		effect_positions.append(effect.position)
	effect_positions.sort()
	effect_positions.push_back(current_segment_text.length()) # End position
	
	for i in range(effect_positions.size()):
		var end_pos = effect_positions[i]
		
		if end_pos > current_pos:
			# Create segment from current_pos to end_pos
			var segment_text = current_segment_text.substr(current_pos, end_pos - current_pos)
			var is_word_mode = (current_char_delay == 0)
			
			var segment_effects = zone_effects.duplicate() if in_zone else {}
			
			var render_seg = RenderSegment.new(
				segment_text,
				current_pos,
				end_pos,
				is_word_mode,
				current_char_delay,
				current_word_speed,
				segment_effects
			)
			segments.append(render_seg)
			
		# Apply effects at this position
		if i < effect_positions.size() - 1:  # Don't process the end marker
			for effect in current_segment_effects:
				if effect.position == end_pos:
					print("Applying effect at position ", end_pos, ": ", effect)
					match effect.get("type", "permanent"):
						"start_zone":
							in_zone = true
							zone_effects = effect.effects.duplicate()
							current_char_delay = effect.effects.get("char_delay", current_char_delay)
							current_word_speed = effect.effects.get("word_speed", current_word_speed)
						"end_zone":
							in_zone = false
							zone_effects.clear()
						"permanent":
							current_char_delay = effect.effects.get("char_delay", current_char_delay)
							current_word_speed = effect.effects.get("word_speed", current_word_speed)
		
		current_pos = end_pos
	
	render_segments = segments
	print("Total render segments created: ", render_segments.size())

func render_next_segment():
	print("=== RENDER_NEXT_SEGMENT ===")
	
	if current_render_index >= render_segments.size():
		finish_current()
		return
	
	var segment = render_segments[current_render_index]
	
	# CHECK FOR SUPER PAUSE AT SEGMENT START
	if check_for_super_pause(segment.start_pos):
		waiting_for_super_pause_input = true
		super_pause_active = true
		character_manager.update_character_talking_state(true)
		return  # Don't start the timer, wait for input
	
	# Apply effects for this segment
	apply_segment_effects(segment)
	
	# Set timer based on segment mode
	if segment.is_word_mode:
		typing_timer.wait_time = 60.0 / segment.word_speed
	else:
		var fps = dialogue_data.get_float("FramesPerSecond", 60.0)
		typing_timer.wait_time = segment.char_delay / fps if segment.char_delay > 0 else 0.016
	
	is_typing = true
	typing_timer.start()

func typing_speed():
	var effective_char_delay = current_char_delay if current_char_delay > 0 else dialogue_data.integers["DelayBetweenCharacters"]
	var effective_word_speed = current_word_speed if current_word_speed > 0 else dialogue_data.integers["TextSpeed"]
	
	if effective_char_delay > 0:
		typing_timer.wait_time = effective_char_delay / fps
	else:
		typing_timer.wait_time = (fps / effective_word_speed)

func switch_rendering_mode(new_word_mode: bool, char_pos: int = -1):
	print("switch_rendering_mode called: new_word_mode=", new_word_mode, " char_pos=", char_pos)
	
	# Prevent infinite loops
	if is_switching_modes:
		return
	is_switching_modes = true
	
	typing_timer.stop()
	
	if char_pos == -1:
		char_pos = text_manager.get_current_position() if not text_manager.is_in_word_mode() else text_manager.get_current_word_index()
	
	text_manager.switch_rendering_mode(new_word_mode, char_pos)
	typing_speed()
	typing_timer.start()
	
	is_switching_modes = false

func check_for_super_pause(position: int) -> bool:
	for effect_change in current_segment_effects:
		if effect_change.position == position:
			if effect_change.effects.get("super_pause", false):
				return true
	return false

func _render_timer():
	print("=== RENDER_TIMER CALLED ===")
	
	if character_manager.is_entrance_active():
		return
	
	if current_render_index >= render_segments.size():
		return
	
	var segment = render_segments[current_render_index]
	
	var has_more = false
	
	if segment.is_word_mode:
		has_more = text_manager.show_next_word()
	else:
		has_more = text_manager.show_next_character()
	
	# Apply effects to current position
	var current_pos = text_manager.get_current_position() - 1
	
	if current_pos >= 0:
		apply_position_effects(current_pos)
		
		# CHECK FOR SUPER PAUSE HERE
		if check_for_super_pause(current_pos):
			waiting_for_super_pause_input = true
			super_pause_active = true
			character_manager.update_character_talking_state(true)  # Show waiting state
			typing_timer.stop()
			return  # Stop rendering until user input
		
		# Play sound for non-space characters
		var char = current_segment_text[current_pos] if current_pos < current_segment_text.length() else ""
		if char != " " and char != "\n":
			character_manager.play_sound()
	
	# Check if current segment is done
	if not has_more or text_manager.get_current_position() >= segment.end_pos:
		print("Segment complete, advancing...")
		current_render_index += 1
		typing_timer.stop()
		
		if current_render_index < render_segments.size():
			# Small delay between segments
			await get_tree().create_timer(0.05).timeout
			render_next_segment()
		else:
			finish_current()

func apply_segment_effects(segment: RenderSegment):
	# Apply effects that happen at segment start
	for effect_change in current_segment_effects:
		if effect_change.position == segment.start_pos:
			var image_key = effect_change.effects.get("change_image", "")
			if image_key != "":
				character_manager.change_character_image(image_key)
			
			var sound_key = effect_change.effects.get("play_sound", "")
			if sound_key != "":
				character_manager.play_effect_sound(sound_key)
			
			var popup_key = effect_change.effects.get("popup_image", "")
			if popup_key != "":
				character_manager.show_popup_image(popup_key)

func apply_position_effects(position: int):
	
	if current_render_index >= render_segments.size():
		return
		
	var segment = render_segments[current_render_index]
	var current_pos = text_manager.get_current_position()
	var previous_pos = current_pos - 1
	
	if segment.is_word_mode:
		var word_start = previous_pos
		
		while word_start > segment.start_pos and current_segment_text[word_start] != " " and current_segment_text[word_start] != "\n":
			word_start -= 1
		
		if word_start > segment.start_pos and (current_segment_text[word_start] == " " or current_segment_text[word_start] == "\n"):
			word_start += 1
		
		for char_pos in range(word_start, current_pos):
			apply_single_character_effects(char_pos)
	else:
		if previous_pos >= 0:
			apply_single_character_effects(previous_pos)

func apply_single_character_effects(char_pos: int):
	# Apply effects to a single character position
	var active_effects = get_active_effects_at_position(char_pos)
	
	if active_effects.get("ripple", 0) > 0:
		var labels = text_manager.get_text_labels()
		if char_pos < labels.size():
			effects_manager.ripple_targeted(labels[char_pos], active_effects["ripple"])
	
	if active_effects.get("jitter", 0) > 0:
		effects_manager.apply_jitter_to_position(char_pos, active_effects["jitter"])
	
	if active_effects.get("wiggle", 0) > 0:
		effects_manager.apply_wiggle_to_position(char_pos, active_effects["wiggle"])
	
	if active_effects.get("shake", 0) > 0:
		effects_manager.apply_shake_to_position(char_pos, active_effects["shake"])

func get_active_effects_at_position(char_pos: int) -> Dictionary:
	var active_effects = {
		"ripple": 0,
		"jitter": 0,
		"wiggle": 0,
		"shake": 0
	}
	
	var in_zone = false
	var zone_effects = {}
	
	# Process effects in order to determine what's active at char_pos
	for effect_change in current_segment_effects:
		
		if effect_change.position <= char_pos:
			match effect_change.get("type", "permanent"):
				"start_zone":
					in_zone = true
					zone_effects = effect_change.effects.duplicate()
				"end_zone":
					in_zone = false
					zone_effects.clear()
				"permanent":
					# Permanent effects override defaults
					for key in active_effects.keys():
						if effect_change.effects.has(key):
							active_effects[key] = effect_change.effects[key]
					print("    PERMANENT: ", effect_change.effects)
	
	# Apply zone effects if we're in a zone
	if in_zone:
		print("  IN ZONE, applying: ", zone_effects)
		for key in active_effects.keys():
			if zone_effects.has(key):
				active_effects[key] = zone_effects[key]
	else:
		print("  NOT IN ZONE")
	return active_effects

func _on_entrance_completed():
	pass

func display_choices():
	clear_choice_buttons()
	show_choice_container()
	create_choice_buttons()
	waiting_for_input = true
	character_manager.update_character_talking_state(waiting_for_input)

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
	
	text_manager.finish_rendering()
	
	waiting_for_input = true
	character_manager.update_character_talking_state(true)

func next():
	if not waiting_for_input:
		return
	
	print("next() called, current_segment_index: ", current_segment_index, " total segments: ", full_dialogue_segments.size())
	
	text_manager.clear_all_text()
	
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
		character_manager.update_character_talking_state(false)
		
		# Start rendering
		if current_render_index < render_segments.size():
			var segment = render_segments[current_render_index]
			apply_segment_effects(segment)
			
			if segment.is_word_mode:
				typing_timer.wait_time = 60.0 / segment.word_speed
			else:
				var fps = dialogue_data.get_float("FramesPerSecond", 60.0)
				typing_timer.wait_time = segment.char_delay / fps if segment.char_delay > 0 else 0.016
			
			is_typing = true
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
			character_manager.update_character_talking_state(false)
			
			# Start rendering
			if current_render_index < render_segments.size():
				var segment = render_segments[current_render_index]
				apply_segment_effects(segment)
				
				if segment.is_word_mode:
					typing_timer.wait_time = 60.0 / segment.word_speed
				else:
					var fps = dialogue_data.get_float("FramesPerSecond", 60.0)
					typing_timer.wait_time = segment.char_delay / fps if segment.char_delay > 0 else 0.016
				
				is_typing = true
				typing_timer.start()
		elif is_typing:
			skip()
		elif waiting_for_input:
			next()
