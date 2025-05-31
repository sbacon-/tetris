extends MarginContainer

@onready var high_score_names: Array[Label] = [%Name1,%Name2,%Name3,%Name4,%Name5]
@onready var high_scores: Array[Label] = [%Score1,%Score2,%Score3,%Score4,%Score5]

func _ready() -> void:
	refresh_scores()

func refresh_scores() -> void:
	for index in range(5):
		high_scores[index].text = str(GlobalVars.high_scores[index][0])
		high_score_names[index].text = GlobalVars.high_scores[index][1]
