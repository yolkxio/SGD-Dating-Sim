extends Resource
class_name CharacterData

@export var character_name: String = ""
@export var character_id: String = ""

@export var dialogue_text_files: Array[String] = []

@export var character_images: Dictionary = {}

@export var character_sounds: Dictionary = {}

@export var character_variables: Dictionary = {
	"will talk": true,
}
