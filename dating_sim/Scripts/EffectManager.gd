extends Node
class_name EffectManager

signal effect_sound_requested(sound_key: String)
signal character_image_change_requested(image_key: String)
signal popup_image_requested(image_key: String)

var dialogue_data: DialogueData
var text_labels: Array = []
var fps: float = 60.0

# Effect timers
var ripple_timer: Timer
var effect_update_timer: Timer

# Effect tracking arrays
var ripple_positions: Array = []
var shake_effects: Array = []
var jitter_effects: Array = []
var wiggle_effects: Array = []

func initialize(data: DialogueData):
	dialogue_data = data
	fps = dialogue_data.get_float("FramesPerSecond", 60.0)
	setup_timers()

func setup_timers():
	ripple_timer = Timer.new()
	add_child(ripple_timer)
	ripple_timer.timeout.connect(_ripple_timer)
	ripple_timer.wait_time = dialogue_data.get_float("RippleTimerInterval", 0.016)
	ripple_timer.start()
	
	effect_update_timer = Timer.new()
	add_child(effect_update_timer)
	effect_update_timer.timeout.connect(_update_effects)
	effect_update_timer.wait_time = dialogue_data.get_float("EffectUpdateTimerInterval", 0.016)
	effect_update_timer.start()

func set_text_labels(labels: Array):
	text_labels = labels

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
				elif effect_content.begins_with("}"):
					# Handle end zone, but also process any effects that come after }
					effects_data.append({
						"position": clean_text.length(),
						"effects": {},
						"type": "end_zone"
					})
					
					# If there are effects after the }, process them as permanent
					if effect_content.length() > 1:
						var remaining_effects = effect_content.substr(1)  # Skip the }
						var new_effects = parse_effects(remaining_effects)
						effects_data.append({
							"position": clean_text.length(),
							"effects": new_effects,
							"type": "permanent"
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
		var jitter_intensity = number_str.to_int() if number_str != "" else dialogue_data.get_integer("DefaultJitterIntensity", 2)
		effects["jitter"] = jitter_intensity
	elif effect_str.begins_with("^"):
		var number_str = effect_str.substr(1)
		var shake_frames = number_str.to_int()
		effects["shake"] = shake_frames
	elif effect_str.begins_with("&"):
		var number_str = effect_str.substr(1)
		var wiggle_intensity = number_str.to_int() if number_str != "" else dialogue_data.get_integer("DefaultWiggleIntensity", 5)
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

func apply_effects_to_position(position: int, segment_effects: Array, current_segment_word_positions: Array, is_word_mode: bool, processed_entrance_positions: Array):
	var text_pos = position
	if is_word_mode and position < current_segment_word_positions.size():
		text_pos = current_segment_word_positions[position]
	
	for effect_change in segment_effects:
		if effect_change.position == text_pos:
			var image_key = effect_change.effects.get("change_image", "")
			if image_key != "":
				if image_key == "entrance" and effect_change.position in processed_entrance_positions:
					continue
				character_image_change_requested.emit(image_key)
			
			var sound_key = effect_change.effects.get("play_sound", "")
			if sound_key != "":
				effect_sound_requested.emit(sound_key)
			
			var popup_key = effect_change.effects.get("popup_image", "")
			if popup_key != "":
				popup_image_requested.emit(popup_key)
	
	# Apply ripple effect
	var current_ripple_value = 0
	for effect_change in segment_effects:
		if effect_change.position <= text_pos:
			if effect_change.get("type") == "start_zone":
				current_ripple_value = effect_change.effects.get("ripple", 0)
			elif effect_change.get("type") == "end_zone":
				current_ripple_value = 0
			elif effect_change.get("type") == "permanent":
				current_ripple_value = effect_change.effects.get("ripple", 0)
	
	if current_ripple_value > 0 and position < text_labels.size():
		ripple_targeted(text_labels[position], current_ripple_value)
	
	# Apply zone effects
	var in_zone = false
	var zone_jitter = 0
	var zone_wiggle = 0
	var zone_shake = 0
	
	for effect_change in segment_effects:
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
		"duration": ripple_frames * (1000.0 / fps)
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
				var ripple_strength = time_factor * dialogue_data.get_float("RippleStrengthMultiplier", 0.4)
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

func apply_shake_to_position(position: int, frames: int, intensity: int = -1):
	if intensity == -1:
		intensity = dialogue_data.get_integer("DefaultShakeIntensity", 3)
	
	if position < text_labels.size() and is_instance_valid(text_labels[position]):
		var shake_data = {
			"label": text_labels[position],
			"start_time": Time.get_ticks_msec(),
			"duration": frames * (1000.0 / fps),
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

func _update_effects():
	var current_time = Time.get_ticks_msec()
	
	# Update jitter effects
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
	
	# Update shake effects
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
	
	# Update wiggle effects
	for wiggle_data in wiggle_effects:
		if is_instance_valid(wiggle_data.label) and wiggle_data.active:
			var wiggle_rotation = sin(current_time * dialogue_data.get_float("WiggleTimeMultiplier", 0.01)) * deg_to_rad(wiggle_data.intensity)
			wiggle_data.label.rotation = wiggle_rotation

func clear_effects():
	ripple_positions.clear()
	jitter_effects.clear()
	wiggle_effects.clear()
	shake_effects.clear()
