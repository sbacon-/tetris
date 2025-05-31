extends Node
@onready var double: AudioStreamPlayer = $double
@onready var gameover: AudioStreamPlayer = $gameover
@onready var harddrop: AudioStreamPlayer = $harddrop
@onready var hold: AudioStreamPlayer = $hold
@onready var levelup: AudioStreamPlayer = $levelup
@onready var lockdown: AudioStreamPlayer = $lockdown
@onready var move: AudioStreamPlayer = $move
@onready var rotate: AudioStreamPlayer = $rotate
@onready var single: AudioStreamPlayer = $single
@onready var softdrop: AudioStreamPlayer = $softdrop
@onready var tetris: AudioStreamPlayer = $tetris
@onready var triple: AudioStreamPlayer = $triple

@onready var maintheme: AudioStreamPlayer = $maintheme
@onready var menu: AudioStreamPlayer = $menu

func play(track: String):
	match track:
		"double":
			double.play()
		"gameover":
			maintheme.stop()
			gameover.play()
		"harddrop":
			harddrop.play()
		"hold":
			hold.play()
		"levelup":
			levelup.play()
		"lockdown":
			lockdown.play()
		"move":
			move.play()
		"rotate":
			rotate.play()
		"single":
			single.play()
		"softdrop":
			softdrop.play()
		"tetris":
			tetris.play()
		"triple":
			triple.play()
		"maintheme":
			menu.stop()
			maintheme.play()
		"menu":
			maintheme.stop()
			menu.play()
		_:
			print("not found: "+track)
