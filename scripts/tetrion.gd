extends Node2D
@onready var matrix: TileMapLayer = $Matrix
@onready var lockdown_timer: Timer = $LockdownTimer
@onready var generation_timer: Timer = $GenerationTimer
@onready var fall_timer: Timer = $FallTimer
@onready var left_auto_repeat_timer: Timer = $LeftAutoRepeatTimer
@onready var right_auto_repeat_timer: Timer = $RightAutoRepeatTimer
@onready var break_particle: PackedScene = preload("res://scenes/break_particle.tscn")
@onready var time_value: Label = %TimeValue
@onready var score_value: Label = %ScoreValue
@onready var level_value: Label = %LevelValue
@onready var lines_value: Label = %LinesValue
@onready var goal_value: Label = %GoalValue
@onready var tetrises_value: Label = %TetrisesValue
@onready var tspins_value: Label = %TspinsValue
@onready var combos_value: Label = %CombosValue
@onready var tpm_value: Label = %TPMValue
@onready var lpm_value: Label = %LPMValue
@onready var score_notification: Label = %ScoreNotification
@onready var player_name: LineEdit = %PlayerName
@onready var high_score_container: MarginContainer = %HighScoreContainer
@onready var send_score_button: Button = %SendScoreButton
@onready var game_over_container: MarginContainer = %GameOver


enum Tetrimino {O, I, T, L, J, S, Z, NONE}
enum Facing {NORTH, EAST, SOUTH, WEST}

var bag_full: Array[Tetrimino] = [Tetrimino.O, Tetrimino.I, Tetrimino.T, Tetrimino.L, Tetrimino.J, Tetrimino.S, Tetrimino.Z]
#var bag_full: Array[Tetrimino] = [Tetrimino.T, Tetrimino.T, Tetrimino.T, Tetrimino.T, Tetrimino.T, Tetrimino.T, Tetrimino.T]
var bag: Array[Tetrimino]

var active_piece: Tetrimino
var active_coords: Array[Vector2i]
var active_facing: Facing
var ghost_piece_coords: Array[Vector2i]
var locked: bool = true

var held_piece: Tetrimino = Tetrimino.NONE
var can_hold: bool = true
var next_queue: Array[Tetrimino]
var soft_drop: bool = false
var hard_drop_distance: int = 20
var left_autorepeat: bool = false
var right_autorepeat: bool = false

var tspin_check: bool = false
var tspin: bool = false
var tspinmini: bool = false
var backtoback: bool = false
var notification_tween: Tween

var time: int = 0
var score: int = 0
var level: int = 1
var lines: int = 0
var goal: int = 5
var tetrises: int = 0
var tspins: int = 0
var combos: int = 0
var tpm: int = 0
var lpm: int = 0

var marked_for_destruction: Array[int] = []

func _ready() -> void:
	bag = bag_full.duplicate()
	bag.shuffle()
	for i in range(7):
		next_queue.push_back(get_next_piece())
	fall_timer.wait_time = pow((0.8-((level-1)*0.007)),level-1)
	while level < GlobalVars.starting_level:
		level_up()

func _process(_delta: float) -> void:
	clear()
	if !locked:
		if Input.is_action_just_pressed("move_left") || (Input.is_action_pressed("move_left") && left_autorepeat):
			move_left()
			right_autorepeat = false
			if left_auto_repeat_timer.is_stopped():
				left_auto_repeat_timer.start()
		if Input.is_action_just_pressed("move_right") || (Input.is_action_pressed("move_right") && right_autorepeat):
			move_right()
			left_autorepeat = false
			if right_auto_repeat_timer.is_stopped():
				right_auto_repeat_timer.start()
		if Input.is_action_just_pressed("rotate_clockwise"):
			var target_facing= wrap(active_facing+1, Facing.NORTH, Facing.WEST+1)
			rotate_piece(active_facing,target_facing)
		elif Input.is_action_just_pressed("rotate_counterclockwise"):
			var target_facing= wrap(active_facing-1, Facing.NORTH, Facing.WEST+1)
			rotate_piece(active_facing,target_facing)
		if Input.is_action_just_pressed("hold"):
			hold_piece()
		if Input.is_action_just_pressed("hard_drop"):
			hard_drop()
	if Input.is_action_just_pressed("soft_drop"):
		soft_drop = true
		fall_timer.wait_time = pow((0.8-((level-1)*0.007)),level-1)/20
		fall_timer.start()
	if Input.is_action_just_released("soft_drop"):
		soft_drop = false
		fall_timer.wait_time = pow((0.8-((level-1)*0.007)),level-1)
		
	generate_ghost_piece()
	redraw()
	
	if Input.is_action_just_released("move_left"):
		left_autorepeat = false
		right_autorepeat = false
		left_auto_repeat_timer.stop()
	if Input.is_action_just_released("move_right"):
		left_autorepeat = false
		right_autorepeat = false
		right_auto_repeat_timer.stop()
	if Input.is_action_pressed("move_left") && Input.is_action_pressed("move_right"):
		left_autorepeat = false
		right_autorepeat = false
		left_auto_repeat_timer.stop()
		right_auto_repeat_timer.stop()

func clear() -> void:
	clear_ghost_piece()
	clear_piece()
	clear_held_piece()
	clear_next_queue()

func redraw() -> void:
	draw_ghost_piece()
	draw_piece()
	draw_held_piece()
	draw_next_queue()
	update_labels()

func draw_piece():
	for mino in active_coords:
		matrix.set_cell(mino,1,Vector2i(active_piece,0))

func clear_piece():
	for mino in active_coords:
		matrix.erase_cell(mino)

func draw_ghost_piece():
	for mino in ghost_piece_coords:
		matrix.set_cell(mino,1,Vector2i(active_piece,1))

func clear_ghost_piece():
	for mino in ghost_piece_coords:
		matrix.erase_cell(mino)

func draw_held_piece():
	for mino in get_spawn_offset(held_piece):
		mino.x += -4
		mino.y += 19
		matrix.set_cell(mino, 1, Vector2i(held_piece,0))

func clear_held_piece():
	for x in range(-5,-1):
		matrix.erase_cell(Vector2i(x,20))
		matrix.erase_cell(Vector2i(x,19))

func draw_next_queue():
	for y in range(0,6):
		for mino in get_spawn_offset(next_queue[y]):
			mino.x += 14
			mino.y += 19 - 3*y
			matrix.set_cell(mino, 1, Vector2i(next_queue[y],0))

func clear_next_queue():
	for x in range (13,17):
		for y in range (4,21):
			matrix.erase_cell(Vector2i(x,y))

func update_labels():
	var minutes = time/(10.0*60.0)
	var seconds = int(time/10.0)%60
	time_value.text = (str(int(minutes))+(":"if seconds > 10 else ":0") +str(seconds)+"."+str(time%10))
	
	var score_string = str(score)
	while score_string.length()<9:
		score_string = "0" + score_string
	score_value.text = score_string
	
	level_value.text = ("0" if level < 10 else "") +str(level)
	lines_value.text = ("0" if lines < 10 else "") +str(lines)
	goal_value.text = ("0" if goal < 10 else "") +str(goal)
	
	tetrises_value.text = ("0" if tetrises < 10 else "") +str(tetrises)
	tspins_value.text = ("0" if tspins < 10 else "") +str(tspins)
	combos_value.text = ("0" if combos < 10 else "") +str(combos)
	if time!=0:
		lpm = int(float(lines)/minutes)
		tpm_value.text = str(int(tpm/minutes))
	lpm_value.text = str(lpm)
	

func get_next_piece() -> Tetrimino:
	var next_bag = bag.pop_front()
	if bag.is_empty():
		bag = bag_full.duplicate()
		bag.shuffle()
	return next_bag

func _on_generation_timer_timeout() -> void:
	spawn_piece()
	can_hold = true
	generate_ghost_piece()
	redraw()

func spawn_piece() -> void:
	tpm += 4
	active_piece = next_queue.pop_front()
	next_queue.push_back(get_next_piece())
	var spawn_offsets = get_spawn_offset(active_piece)
	active_coords = []
	for coordinate in spawn_offsets:
		active_coords.push_back(Vector2i(coordinate.x + 5, coordinate.y + 21))
	active_facing = Facing.NORTH
	for cell in active_coords:
		if matrix.get_cell_atlas_coords(cell).y != -1:
			game_over()
			break;
	locked=false
	tspin_check = false
	fall()

func fall() -> void:
	if can_fall():
		if !lockdown_timer.is_stopped():
			lockdown_timer.stop()
		for i in range(4):
			active_coords[i].y -= 1
		if soft_drop:
			score += 1
			AudioStreamManager.play("softdrop")
		tspin_check = false
	else:
		if lockdown_timer.is_stopped():
			lockdown_timer.start()

func can_fall() -> bool:
	for mino in active_coords:
		if is_cell_occupied(Vector2i(mino.x, mino.y-1)):
			return false
	return !locked

func _on_fall_timer_timeout() -> void:
	clear()
	fall()
	redraw()

func _on_lockdown_timer_timeout() -> void:
	if !can_fall():
		hard_drop()

func generate_ghost_piece() -> void:
	if active_coords.is_empty():
		return
	elif ghost_piece_coords == active_coords:
		hard_drop_distance=0
		return
	var distance = 0
	var fallen = false
	while !fallen:
		distance += 1
		for mino in active_coords:
			if is_cell_occupied(Vector2i(mino.x,mino.y-distance)):
				fallen=true
	ghost_piece_coords = active_coords.duplicate()
	for i in range(4):
		ghost_piece_coords[i].y -= distance-1
	hard_drop_distance = distance-1

func hard_drop() -> void:
	if hard_drop_distance > 0:
		score +=  2 * hard_drop_distance
		AudioStreamManager.play("harddrop")
		tspin_check = false
	else:
		AudioStreamManager.play("lockdown")
	clear()
	active_coords = ghost_piece_coords.duplicate()
	redraw()
	var min_y = 22
	for cell in active_coords:
		if cell.y < min_y:
			min_y = cell.y
	if min_y >= 21:
		game_over()
	locked = true
	pattern_phase()
	generation_timer.start()

func move_left() -> void:
	if can_move_left():
		for i in range(4):
			active_coords[i].x -= 1
		AudioStreamManager.play("move")
		tspin_check = false

func can_move_left() -> bool:
	for mino in active_coords:
		if is_cell_occupied(Vector2i(mino.x-1,mino.y)):
			return false
	return !active_coords.is_empty()

func move_right() -> void:
	if can_move_right():
		for i in range(4):
			active_coords[i].x += 1
		AudioStreamManager.play("move")
		tspin_check = false

func can_move_right() -> bool:
	for mino in active_coords:
		if is_cell_occupied(Vector2i(mino.x+1,mino.y)):
			return false
	return !active_coords.is_empty()

func is_cell_occupied(cell: Vector2i) -> bool:
	if active_coords.find(cell) != -1:
		return false
	if cell.x < 1 || cell.x > 10 || cell.y < 1  :
		return true
	var occupant = matrix.get_cell_atlas_coords(cell)
	return occupant.y != -1

func are_cells_occupied(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if is_cell_occupied(cell):
			return true
	return false

func get_spawn_offset(piece_type: Tetrimino) -> Array:
	match piece_type:
		Tetrimino.O:
			return [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0), Vector2i(1,1)]
		Tetrimino.I:
			return [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)]
		Tetrimino.T:
			return [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)]
		Tetrimino.L:
			return [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(1,1)]
		Tetrimino.J:
			return [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(-1,1)]
		Tetrimino.S:
			return [Vector2i(-1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)]
		Tetrimino.Z:
			return [Vector2i(1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(-1,1)]
	return []

func hold_piece():
	if can_hold:
		clear()
		if held_piece != Tetrimino.NONE:
			next_queue.push_front(held_piece)
		held_piece = active_piece
		AudioStreamManager.play("hold")
		tpm-=4
		spawn_piece()
	can_hold = false

func rotate_piece(facing: Facing, target_facing: Facing) -> void:
	if abs(facing-target_facing)==2:
		return
	var transformation = get_piece_transform(facing,target_facing)
	var translation = get_piece_translate(facing,target_facing)
	var target_coords = active_coords.duplicate()
	for i in range(4):
		target_coords[i] += transformation[i]
	while are_cells_occupied(target_coords) && !translation.is_empty():
		var point = translation.pop_front()
		for i in range(4):
			target_coords[i] += point
	if !are_cells_occupied(target_coords):
		active_coords = target_coords
		active_facing = target_facing
		AudioStreamManager.play("rotate")
		tspin_check = active_piece == Tetrimino.T

func get_piece_translate(facing: Facing, target_facing: Facing) -> Array:
	match active_piece:
		Tetrimino.O:
			return [Vector2i(0,0),Vector2i(0,0),Vector2i(0,0),Vector2i(0,0)]
		Tetrimino.I:
			var translation = [
				[[],[Vector2i(-2,0),Vector2i(3,0),Vector2i(-3,-1),Vector2i(3,3)],[],[[Vector2i(-1,0),Vector2i(3,0),Vector2i(-3,2),Vector2i(3,-3)]]],
				[[Vector2i(2,0),Vector2i(-3,0),Vector2i(1,3),Vector2i(-3,-3)],[],[Vector2i(-1,0),Vector2i(3,0),Vector2i(-3,-2),Vector2i(3,3)],[]],
				[[],[Vector2i(1,0),Vector2i(-3,0),Vector2i(3,-2),Vector2i(-3,3)],[],[Vector2i(2,0),Vector2i(-3,0),Vector2i(3,1),Vector2i(-3,-3)]],
				[[Vector2i(1,0),Vector2i(-3,0),Vector2i(3,-2),Vector2i(-3,3)],[],[Vector2i(-2,0),Vector2i(3,0),Vector2i(-1,-3),Vector2i(3,3)],[]]
			]
			return translation[facing][target_facing]
		Tetrimino.T:
			var translation = [
				[[],[Vector2i(-1,0),Vector2i(0,1),Vector2i(0,0),Vector2i(0,-3)],[],[Vector2i(1,0),Vector2i(0,1),Vector2i(0,0),Vector2i(0,-3)]],
				[[Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,3),Vector2i(1,0)],[],[Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,3),Vector2i(1,0)],[]],
				[[],[Vector2i(-1,0),Vector2i(0,0),Vector2i(1,-3),Vector2i(-1,0)],[],[Vector2i(1,0),Vector2i(0,0),Vector2i(-1,-3),Vector2i(1,0)]],
				[[Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,3),Vector2i(-1,0)],[],[Vector2i(-2,0),Vector2i(3,0),Vector2i(-1,-3),Vector2i(3,3)],[]]
			]
			return translation[facing][target_facing]
		_:
			var translation = [
				[[],[Vector2i(-1,0),Vector2i(0,1),Vector2i(1,-3),Vector2i(-1,0)],[],[Vector2i(1,0),Vector2i(0,1),Vector2i(-1,-3),Vector2i(1,0)]],
				[[Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,3),Vector2i(1,0)],[],[Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,3),Vector2i(1,0)],[]],
				[[],[Vector2i(-1,0),Vector2i(0,1),Vector2i(1,-3),Vector2i(-1,0)],[],[Vector2i(1,0),Vector2i(0,1),Vector2i(-1,-3),Vector2i(1,0)]],
				[[Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,3),Vector2i(-1,0)],[],[Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,3),Vector2i(-1,0)],[]]
			]
			return translation[facing][target_facing]

func get_piece_transform(facing: Facing, target_facing: Facing) -> Array:
	match active_piece:
		Tetrimino.O:
			return [Vector2i(0,0),Vector2i(0,0),Vector2i(0,0),Vector2i(0,0)]
		Tetrimino.I:
			var transformation = [
				[[],[Vector2i(2,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,-2)],[],[Vector2i(1,-2),Vector2i(0,-1),Vector2i(-1,0),Vector2i(-2,1)]],
				[[Vector2i(-2,-1),Vector2i(-1,0),Vector2i(0,1),Vector2i(1,2)],[],[Vector2i(1,-2),Vector2i(0,-1),Vector2i(-1,0),Vector2i(-2,1)],[]],
				[[],[Vector2i(-1,2),Vector2i(0,1),Vector2i(1,0),Vector2i(2,-1)],[],[Vector2i(-2,-1),Vector2i(-1,0),Vector2i(0,1),Vector2i(1,2)]],
				[[Vector2i(-1,2),Vector2i(0,1),Vector2i(1,0),Vector2i(2,-1)],[],[Vector2i(2,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,-2)],[]]
			]
			return transformation[facing][target_facing]
		Tetrimino.T:
			var transformation = [
				[[],[Vector2i(1,1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(1,-1)],[],[Vector2i(1,-1),Vector2i(0,0),Vector2i(-1,1),Vector2i(-1,-1)]],
				[[Vector2i(-1,-1),Vector2i(0,0),Vector2i(1,1),Vector2i(-1,1)],[],[Vector2i(1,-1),Vector2i(0,0),Vector2i(-1,1),Vector2i(-1,-1)],[]],
				[[],[Vector2i(-1,1),Vector2i(0,0),Vector2i(1,-1),Vector2i(1,1)],[],[Vector2i(-1,-1),Vector2i(0,0),Vector2i(1,1),Vector2i(-1,1)]],
				[[Vector2i(-1,1),Vector2i(0,0),Vector2i(1,-1),Vector2i(1,1)],[],[Vector2i(1,1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(1,-1)],[]]
			]
			return transformation[facing][target_facing]
		Tetrimino.L:
			var transformation = [
				[[],[Vector2i(1,1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(0,-2)],[],[Vector2i(1,-1),Vector2i(0,0),Vector2i(-1,1),Vector2i(-2,0)]],
				[[Vector2i(-1,-1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,2)],[],[Vector2i(1,-1),Vector2i(0,0),Vector2i(-1,1),Vector2i(-2,0)],[]],
				[[],[Vector2i(-1,1),Vector2i(0,0),Vector2i(1,-1),Vector2i(2,0)],[],[Vector2i(-1,-1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,2)]],
				[[Vector2i(-1,1),Vector2i(0,0),Vector2i(1,-1),Vector2i(2,0)],[],[Vector2i(1,1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(0,-2)],[]]
			]
			return transformation[facing][target_facing]
		Tetrimino.J:
			var transformation = [
				[[],[Vector2i(1,1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(2,0)],[],[Vector2i(1,-1),Vector2i(0,0),Vector2i(-1,1),Vector2i(0,-2)]],
				[[Vector2i(-1,-1),Vector2i(0,0),Vector2i(1,1),Vector2i(-2,0)],[],[Vector2i(1,-1),Vector2i(0,0),Vector2i(-1,1),Vector2i(0,-2)],[]],
				[[],[Vector2i(-1,1),Vector2i(0,0),Vector2i(1,-1),Vector2i(0,2)],[],[Vector2i(-1,-1),Vector2i(0,0),Vector2i(1,1),Vector2i(-2,0)]],
				[[Vector2i(-1,1),Vector2i(0,0),Vector2i(1,-1),Vector2i(0,2)],[],[Vector2i(1,1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(2,0)],[]]
			]
			return transformation[facing][target_facing]
		Tetrimino.S:
			var transformation = [
				[[],[Vector2i(1,1),Vector2i(0,0),Vector2i(1,-1),Vector2i(0,-2)],[],[Vector2i(1,-1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(-2,0)]],
				[[Vector2i(-1,-1),Vector2i(0,0),Vector2i(-1,1),Vector2i(0,2)],[],[Vector2i(1,-1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(-2,0)],[]],
				[[],[Vector2i(-1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(2,0)],[],[Vector2i(-1,-1),Vector2i(0,0),Vector2i(-1,1),Vector2i(0,2)]],
				[[Vector2i(-1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(2,0)],[],[Vector2i(1,1),Vector2i(0,0),Vector2i(1,-1),Vector2i(0,-2)],[]]
			]
			return transformation[facing][target_facing]
		Tetrimino.Z:
			var transformation = [
				[[],[Vector2i(-1,-1),Vector2i(0,0),Vector2i(1,-1),Vector2i(2,0)],[],[Vector2i(-1,1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(0,-2)]],
				[[Vector2i(1,1),Vector2i(0,0),Vector2i(-1,1),Vector2i(-2,0)],[],[Vector2i(-1,1),Vector2i(0,0),Vector2i(-1,-1),Vector2i(0,-2)],[]],
				[[],[Vector2i(1,-1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,2)],[],[Vector2i(1,1),Vector2i(0,0),Vector2i(-1,1),Vector2i(-2,0)]],
				[[Vector2i(1,-1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,2)],[],[Vector2i(-1,-1),Vector2i(0,0),Vector2i(1,-1),Vector2i(2,0)],[]]
			]
			return transformation[facing][target_facing]
	return []

func pattern_phase():
	redraw()
	if tspin_check:
		var corners = get_tspin_coords()
		for index in range(4):
			corners[index] += active_coords[1]
		if is_cell_occupied(corners[0]) && is_cell_occupied(corners[1]) && (is_cell_occupied(corners[2]) || is_cell_occupied(corners[3])):
			tspin = true
		elif is_cell_occupied(corners[2]) && is_cell_occupied(corners[3]) && (is_cell_occupied(corners[0]) || is_cell_occupied(corners[1])):
			tspinmini = true
	active_coords = []
	ghost_piece_coords = []
	for y in range(1,21):
		var row: Array[Vector2i] = []
		for x in range(1,11):
			row.push_back(Vector2i(x,y))
		if are_all_cells_occupied(row):
			marked_for_destruction.push_front(y)
	animate()
	eliminate()

func get_tspin_coords() -> Array:
	var corners = [
		[Vector2i(-1,1),Vector2i(1,1),Vector2i(-1,-1),Vector2i(1,-1)],
		[Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)],
		[Vector2i(1,-1),Vector2i(-1,-1),Vector2i(1,1),Vector2i(-1,1)],
		[Vector2i(-1,-1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(1,1)]
	]
	return corners[active_facing]

func are_all_cells_occupied(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if matrix.get_cell_atlas_coords(cell).y != 0:
			return false
	return true

func animate():
	for row in marked_for_destruction:
		for column in range(1,11):
			var current_particle = break_particle.instantiate()
			var current_cell = Vector2i(column,row)
			matrix.add_child(current_particle)
			current_particle.set_color(matrix.get_cell_atlas_coords(current_cell).x)
			current_particle.position = matrix.map_to_local(current_cell)
			current_particle.play()

func eliminate():
	marked_for_destruction.sort()
	marked_for_destruction.reverse()
	for row in marked_for_destruction:
		for y in range(row, 21):
			for x in range(1,11):
				matrix.set_cell(Vector2i(x,y),1,matrix.get_cell_atlas_coords(Vector2i(x,y+1)))
		lines += 1
	if marked_for_destruction.size() == 0:
		if tspin:
			tspins += 1
			score += 400 * level
			notify("TSPIN")
		if tspinmini:
			tspins += 1
			score += 100 * level
			notify("TSPIN-MINI")
	if marked_for_destruction.size() == 1:
		if tspin:
			tspins += 1
			score += 800 * level
			if backtoback:
				combos += 1
				score += 400 *level
				notify("BACK TO BACK\nTSPIN\nSINGLE")
			else:
				notify("TSPIN\nSINGLE")
			backtoback = true
		elif tspinmini:
			tspins += 1
			score += 200 * level
			if backtoback:
				combos += 1
				score += 100 *level
				notify("BACK TO BACK\nTSPIN-MINI\nSINGLE")
			else:
				notify("TSPIN-MINI\nSINGLE")
			backtoback = true
		else:
			score += 100 * level
			notify("SINGLE")
			backtoback = false
		AudioStreamManager.play("single")
	if marked_for_destruction.size() == 2:
		if tspin:
			tspins += 1
			score += 1200 * level
			if backtoback:
				combos += 1
				score += 600 *level
				notify("BACK TO BACK\nTSPIN-MINI\nDOUBLE")
			else:
				notify("TSPIN\nDOUBLE")
			backtoback = true
		else:
			score += 300 * level
			notify("DOUBLE")
			backtoback = false
		AudioStreamManager.play("double")
	if marked_for_destruction.size() == 3:
		if tspin:
			tspins += 1
			score += 1600 * level
			if backtoback:
				combos += 1
				score += 800 *level
				notify("BACK TO BACK\nTSPIN-MINI\nTRIPLE")
			else:
				notify("TSPIN\nTRIPLE")
			backtoback = true
		else:
			score += 500 * level
			notify("TRIPLE")
			backtoback = false
		AudioStreamManager.play("triple")
	if marked_for_destruction.size() == 4:
		tetrises += 1
		score += 800 * level
		if backtoback:
			combos += 1
			score += 400 *level
			notify("BACK TO BACK\nTETRIS")
		else:
			notify("TETRIS")
		backtoback = true
		AudioStreamManager.play("tetris")
	marked_for_destruction.clear()
	if lines >= goal:
		level_up()
	tspin = false
	tspinmini = false

func notify(text: String):
	if notification_tween:
		notification_tween.kill()
	score_notification.text = text
	score_notification.modulate.a = 1.0
	notification_tween = score_notification.create_tween()
	notification_tween.tween_property(score_notification,"modulate:a", 0.0, 2.0)

func level_up() -> void:
	AudioStreamManager.play("levelup")
	level += 1
	goal += 5 * level
	fall_timer.wait_time = pow((0.8-((level-1)*0.007)),level-1)

func game_over() -> void:
	clear()
	redraw()
	game_over_container.visible = true
	for x in range (1, 11):
		for y in range(1,40):
			if is_cell_occupied(Vector2i(x,y)):
				matrix.set_cell(Vector2i(x,y),1,Vector2i(7,0))
	notify("GAME OVER")
	AudioStreamManager.play("gameover")
	get_tree().paused = true

func _on_timer_timeout() -> void:
	time += 1

func _on_left_auto_repeat_timer_timeout() -> void:
	left_autorepeat = true

func _on_right_auto_repeat_timer_timeout() -> void:
	right_autorepeat = true

func _on_play_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_send_score_button_pressed() -> void:
	send_score_button.disabled = true
	GlobalVars.submit_score([score,player_name.text])
	high_score_container.refresh_scores()

func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	AudioStreamManager.play("menu")
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
