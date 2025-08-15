extends Node
class_name CharacterManager

signal entrance_completed

var dialogue_data: DialogueData
var character_data: CharacterData
var name_tag: NameTag
var audio_player: AudioStreamPlayer
var character_rect: TextureRect

var current_character_image_key: String = ""
var entrance_completed_flag: bool = false
var is_entrance_playing: bool = false
var processed_entrance_positions: Array = []

func initialize(data: DialogueData, char_data: CharacterData, name_tag_ref: NameTag, character_texture_rect: TextureRect):
	dialogue_data = data
	character_data = char_data
	name_tag = name_tag_ref
	character_rect = character_texture_rect
	
	setup_audio()
	setup_name_tag()

func setup_audio():
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)

func setup_name_tag():
	if not name_tag:
		return
	
	if name_tag and character_data:
		name_tag.set_character(character_data)

func set_character(character: CharacterData):
	character_data = character
	
	if name_tag:
		name_tag.set_character(character_data)

func play_sound():
	if character_data and audio_player:
		var talking_sound = character_data.character_sounds.get("talking")
		if talking_sound:
			audio_player.stream = talking_sound
			audio_player.pitch_scale = randf_range(
				dialogue_data.get_float("AudioPitchMin", 0.9), 
				dialogue_data.get_float("AudioPitchMax", 1.1)
			)
			audio_player.play()

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
			var scale_factor = min(screen_size.x / image_size.x, screen_size.y / image_size.y) * dialogue_data.get_float("PopupSizeMultiplier", 0.8)
			
			popup_image.custom_minimum_size = image_size * scale_factor
			popup_image.size = image_size * scale_factor
			popup_image.position = (screen_size - popup_image.size) / 2
			popup_image.scale = Vector2(dialogue_data.get_float("PopupInitialScale", 0.1), dialogue_data.get_float("PopupInitialScale", 0.1))
			popup_image.modulate.a = 0.0
			popup_image.pivot_offset = popup_image.size / 2
			
			get_tree().current_scene.add_child(popup_image)
			_animate_popup(popup_image)

func _animate_popup(popup_image: TextureRect):
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup_image, "scale", Vector2.ONE, dialogue_data.get_float("PopupScaleDuration", 0.3)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(popup_image, "modulate:a", 1.0, dialogue_data.get_float("PopupFadeInDuration", 0.2))
	
	await get_tree().create_timer(dialogue_data.get_float("PopupDisplayDuration", 0.8)).timeout
	
	if is_instance_valid(popup_image):
		var fade_tween = get_tree().create_tween()
		fade_tween.tween_property(popup_image, "modulate:a", 0.0, dialogue_data.get_float("PopupFadeOutDuration", 0.4))
		fade_tween.finished.connect(func(): 
			if is_instance_valid(popup_image):
				popup_image.queue_free()
		)

func change_character_image(image_key: String):
	if not character_data:
		return
		
	if image_key == "entrance":
		if not entrance_completed_flag:
			var entrance_texture = character_data.character_images.get("entrance")
			if entrance_texture:
				await handle_entrance_fade(entrance_texture)
				entrance_completed_flag = true 
				entrance_completed.emit()
		return
	
	var character_image_array = character_data.character_images.get(image_key)
	if character_image_array and character_image_array is Array and character_image_array.size() >= 2:
		current_character_image_key = image_key
		if entrance_completed_flag:
			update_character_talking_state(false)  # Not waiting for input initially

func handle_entrance_fade(entrance_texture: Texture2D):
	is_entrance_playing = true
	
	if character_rect:
		character_rect.texture = entrance_texture
		character_rect.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(character_rect, "modulate:a", 1.0, dialogue_data.get_float("EntranceFadeDuration", 1.0))
		await tween.finished
	
	is_entrance_playing = false
	entrance_completed_flag = true

func handle_entrance_if_needed(segment_effects: Array):
	var entrance_found = false
	
	for effect_change in segment_effects:
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
		entrance_completed_flag = true

func update_character_talking_state(waiting_for_input: bool):
	if is_entrance_playing or not entrance_completed_flag:
		return
		
	if current_character_image_key == "" or not character_data:
		return
		
	var character_image_array = character_data.character_images.get(current_character_image_key)
	if character_image_array and character_image_array is Array and character_image_array.size() >= 2:
		if character_rect:
			if waiting_for_input:
				character_rect.texture = character_image_array[0]  # Idle/waiting state
			else:
				character_rect.texture = character_image_array[1]  # Talking state

func is_entrance_active() -> bool:
	return is_entrance_playing

func is_entrance_done() -> bool:
	return entrance_completed_flag
