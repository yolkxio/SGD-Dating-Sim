extends Node
class_name MusicManager

signal music_fade_completed

var dialogue_data: DialogueData
var current_music_player: AudioStreamPlayer
var fade_music_player: AudioStreamPlayer
var fade_tween: Tween

var current_track_key: String = ""
var is_fading: bool = false
var music_library: Dictionary = {}

func initialize(data: DialogueData):
	dialogue_data = data
	setup_audio_players()

func setup_audio_players():
	current_music_player = AudioStreamPlayer.new()
	add_child(current_music_player)
	current_music_player.volume_db = dialogue_data.get_float("MusicBaseVolume", -10.0)
	current_music_player.bus = dialogue_data.get_string("MusicBus", "Master")
	
	#Secondary player for crossfading
	fade_music_player = AudioStreamPlayer.new()
	add_child(fade_music_player)
	fade_music_player.volume_db = dialogue_data.get_float("MusicBaseVolume", -10.0)
	fade_music_player.bus = dialogue_data.get_string("MusicBus", "Master")

func set_music_library(music_dict: Dictionary):
	"""Set the dictionary of available music tracks"""
	music_library = music_dict

func play_music(track_key: String, fade_duration: float = -1):
	"""Play a music track with optional fade in"""
	if fade_duration == -1:
		fade_duration = dialogue_data.get_float("MusicDefaultFadeDuration", 1.0)
	
	if track_key == "":
		stop_music(fade_duration)
		return
	
	if track_key == current_track_key:
		return
	
	if not music_library.has(track_key):
		print("Warning: Music track not found: ", track_key)
		return
	
	var new_stream = music_library[track_key]
	if not new_stream:
		print("Warning: Invalid music stream for: ", track_key)
		return
	
	print("MusicManager: Playing track: ", track_key, " with stream: ", new_stream)
	current_track_key = track_key
	
	if current_music_player.playing and fade_duration > 0:
		crossfade_to_track(new_stream, fade_duration)
	else:
		# Direct play without fade
		current_music_player.stream = new_stream
		current_music_player.volume_db = dialogue_data.get_float("MusicBaseVolume", -10.0)
		current_music_player.play()

func crossfade_to_track(new_stream: AudioStream, fade_duration: float):
	is_fading = true
	
	fade_music_player.stream = new_stream
	fade_music_player.volume_db = -80.0  # Start silent
	fade_music_player.play()
	
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.set_parallel(true)
	
	var target_volume = dialogue_data.get_float("MusicBaseVolume", -10.0)
	
	# Fade out current player
	fade_tween.tween_property(current_music_player, "volume_db", -80.0, fade_duration)
	# Fade in new player
	fade_tween.tween_property(fade_music_player, "volume_db", target_volume, fade_duration)
	
	await fade_tween.finished
	
	current_music_player.stop()
	var temp_player = current_music_player
	current_music_player = fade_music_player
	fade_music_player = temp_player
	
	is_fading = false
	music_fade_completed.emit()

func stop_music(fade_duration: float = -1):
	"""Stop current music with optional fade out"""
	if fade_duration == -1:
		fade_duration = dialogue_data.get_float("MusicDefaultFadeDuration", 1.0)
	
	current_track_key = ""
	
	if not current_music_player.playing:
		return
	
	if fade_duration > 0:
		is_fading = true
		if fade_tween:
			fade_tween.kill()
		fade_tween = create_tween()
		fade_tween.tween_property(current_music_player, "volume_db", -80.0, fade_duration)
		await fade_tween.finished
		current_music_player.stop()
		current_music_player.volume_db = dialogue_data.get_float("MusicBaseVolume", -10.0)
		is_fading = false
	else:
		current_music_player.stop()

func set_music_volume(volume_db: float, fade_duration: float = 0.0):
	"""Change music volume with optional fade"""
	if fade_duration > 0:
		if fade_tween:
			fade_tween.kill()
		fade_tween = create_tween()
		fade_tween.tween_property(current_music_player, "volume_db", volume_db, fade_duration)
	else:
		current_music_player.volume_db = volume_db

func pause_music():
	"""Pause current music"""
	current_music_player.stream_paused = true

func resume_music():
	"""Resume paused music"""
	current_music_player.stream_paused = false

func is_music_playing() -> bool:
	"""Check if music is currently playing"""
	return current_music_player.playing and not current_music_player.stream_paused

func get_current_track() -> String:
	"""Get the key of the currently playing track"""
	return current_track_key

func is_music_fading() -> bool:
	"""Check if music is currently fading"""
	return is_fading
