extends Control

@onready var level_button: Button = %LevelButton

func _on_play_button_pressed() -> void:
	AudioStreamManager.play("maintheme")
	get_tree().change_scene_to_file("res://scenes/tetrion.tscn")

func _on_level_button_pressed() -> void:
	if GlobalVars.starting_level == 1:
		GlobalVars.starting_level = 5
	elif GlobalVars.starting_level == 15:
		GlobalVars.starting_level = 1
	else:
		GlobalVars.starting_level += 5
	level_button.text = "LEVEL: "+str(GlobalVars.starting_level)

func _on_quit_button_pressed() -> void:
	get_tree().quit()
