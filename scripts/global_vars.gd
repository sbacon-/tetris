extends Node

var starting_level = 1

var high_scores: Array[Array] = [
	[5000,"TET"],
	[4000,"RIS"],
	[3000,"ALP"],
	[2000,"HBR"],
	[1000,"TOM"]
]

func _ready() -> void:
	high_scores.sort()
	high_scores.reverse()

func submit_score(new_score: Array) -> void:
	high_scores.append(new_score)
	high_scores.sort()
	high_scores.reverse()
