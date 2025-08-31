extends Node
class_name BackgroundManager

signal background_fade_completed

var dialogue_data: DialogueData
var background_rect: TextureRect
var fade_background_rect: TextureRect
var fade_tween: Tween

var current_background_key: String = ""
var is_fading: bool = false
var background_library: Dictionary = {}

func initialize(data: DialogueData, bg_texture_rect: TextureRect):
	dialogue_data = data
	background_rect = bg_texture_rect
	setup_fade_background()

func setup_fade_background():
	# Create a secondary TextureRect for crossfading
	fade_background_rect = TextureRect.new()
	fade_background_rect.name = "FadeBackground"
	fade_background_rect.expand_mode = background_rect.expand_mode
	fade_background_rect.stretch_mode = background_rect.stretch_mode
	fade_background_rect.size = background_rect.size
	fade_background_rect.position = background_rect.position
	fade_background_rect.anchor_left = background_rect.anchor_left
	fade_background_rect.anchor_right = background_rect.anchor_right
	fade_background_rect.anchor_top = background_rect.anchor_top
	fade_background_rect.anchor_bottom = background_rect.anchor_bottom
	fade_background_rect.modulate.a = 0.0
	fade_background_rect.z_index = background_rect.z_index - 1
	
	background_rect.get_parent().add_child(fade_background_rect)

func set_background_library(bg_dict: Dictionary):
	background_library = bg_dict

func change_background(bg_key: String, fade_duration: float = -1):
	if fade_duration == -1:
		fade_duration = dialogue_data.get_float("BackgroundDefaultFadeDuration", 1.0)
	
	if bg_key == "":
		# Clear background
		clear_background(fade_duration)
		return
	
	if bg_key == current_background_key:
		return
	
	if not background_library.has(bg_key):
		print("Warning: Background texture not found: ", bg_key)
		return
	
	var new_texture = background_library[bg_key]
	if not new_texture:
		print("Warning: Invalid background texture for: ", bg_key)
		return
	
	print("BackgroundManager: Changing to background: ", bg_key)
	current_background_key = bg_key
	
	if background_rect.texture != null and fade_duration > 0:
		crossfade_to_background(new_texture, fade_duration)
	else:
		# Direct change without fade
		background_rect.texture = new_texture
		background_rect.modulate.a = 1.0

func crossfade_to_background(new_texture: Texture2D, fade_duration: float):
	is_fading = true
	
	fade_background_rect.texture = new_texture
	fade_background_rect.modulate.a = 0.0
	fade_background_rect.z_index = background_rect.z_index + 1
	
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	# Fade out current background
	fade_tween.tween_property(background_rect, "modulate:a", 0.0, fade_duration)
	# Fade in new background
	fade_tween.tween_property(fade_background_rect, "modulate:a", 1.0, fade_duration)
	
	await fade_tween.finished
	
	background_rect.texture = fade_background_rect.texture
	background_rect.modulate.a = 1.0
	fade_background_rect.modulate.a = 0.0
	fade_background_rect.z_index = background_rect.z_index - 1  # Put fade bg back behind
	
	is_fading = false
	background_fade_completed.emit()

func clear_background(fade_duration: float = -1):
	if fade_duration == -1:
		fade_duration = dialogue_data.get_float("BackgroundDefaultFadeDuration", 1.0)
	
	current_background_key = ""
	
	if background_rect.texture == null:
		return
	
	if fade_duration > 0:
		is_fading = true
		if fade_tween:
			fade_tween.kill()
		fade_tween = create_tween()
		fade_tween.tween_property(background_rect, "modulate:a", 0.0, fade_duration)
		await fade_tween.finished
		background_rect.texture = null
		background_rect.modulate.a = 1.0
		is_fading = false
	else:
		background_rect.texture = null

func set_background_immediately(bg_key: String):
	if bg_key == "":
		background_rect.texture = null
		current_background_key = ""
		return
	
	if not background_library.has(bg_key):
		print("Warning: Background texture not found: ", bg_key)
		return
	
	var texture = background_library[bg_key]
	if texture:
		background_rect.texture = texture
		background_rect.modulate.a = 1.0
		current_background_key = bg_key

func get_current_background() -> String:
	return current_background_key

func is_background_fading() -> bool:
	return is_fading
