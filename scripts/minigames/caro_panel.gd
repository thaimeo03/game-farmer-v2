class_name CaroPanel
extends PanelContainer
## 2D overlay for caro (gomoku) against the AI. Wins pay by difficulty, a few per day.

const REWARD: Array[int] = [10, 30, 60]
const LEVELS: Array[String] = ["Dễ", "Vừa", "Khó"]
const DAILY_WINS := 5

var game: CaroGame
var level := 0
var thinking := false

var _status: Label
var _cells: Array[Button] = []


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -260.0
	offset_right = 260.0
	offset_top = -265.0
	offset_bottom = 265.0
	var box := VBoxContainer.new()
	add_child(box)
	var title := Label.new()
	title.text = "Cờ Caro — 5 quân liền nhau thắng"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	box.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for i in LEVELS.size():
		var b := Button.new()
		b.text = "%s (+%d xu)" % [LEVELS[i], REWARD[i]]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(start.bind(i))
		row.add_child(b)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var grid := GridContainer.new()
	grid.columns = CaroGame.SIZE
	grid.add_theme_constant_override(&"h_separation", 1)
	grid.add_theme_constant_override(&"v_separation", 1)
	box.add_child(grid)
	for y in CaroGame.SIZE:
		for x in CaroGame.SIZE:
			var c := Button.new()
			c.custom_minimum_size = Vector2(26, 26)
			c.focus_mode = Control.FOCUS_NONE
			c.add_theme_font_size_override(&"font_size", 16)
			c.pressed.connect(click.bind(x, y))
			grid.add_child(c)
			_cells.append(c)
	var close := Button.new()
	close.text = "Đóng"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func() -> void: (get_tree().get_first_node_in_group(&"hud") as Hud).close_panels())
	box.add_child(close)
	start(0)


func start(lvl: int) -> void:
	level = lvl
	game = CaroGame.new()
	thinking = false
	_status.text = "Mức %s — bạn đi trước (X). Còn %d ván thắng có thưởng hôm nay." % [LEVELS[level], DAILY_WINS - GameState.daily_count("caro_win")]
	_refresh()


func click(x: int, y: int) -> void:
	if thinking or game.winner != 0 or not game.play(x, y, 1):
		return
	_refresh()
	if game.winner != 0:
		_finish()
		return
	thinking = true
	_status.text = "Máy đang nghĩ..."
	await get_tree().create_timer(0.35).timeout
	var m := game.ai_move(level)
	game.play(m.x, m.y, 2)
	thinking = false
	_refresh()
	if game.winner != 0:
		_finish()
	else:
		_status.text = "Lượt của bạn (X)"


func _finish() -> void:
	match game.winner:
		1:
			if GameState.daily_use("caro_win", DAILY_WINS):
				GameState.earn(REWARD[level])
				Progression.reward(&"race")
				_status.text = "Bạn thắng! +%d xu" % REWARD[level]
			else:
				_status.text = "Bạn thắng! (hết thưởng hôm nay)"
		2:
			_status.text = "Máy thắng rồi. Chọn mức để chơi lại."
		_:
			_status.text = "Hòa!"


func _refresh() -> void:
	for y in CaroGame.SIZE:
		for x in CaroGame.SIZE:
			var v := game.at(x, y)
			var c := _cells[y * CaroGame.SIZE + x]
			c.text = "X" if v == 1 else ("O" if v == 2 else "")
			c.add_theme_color_override(&"font_color", Color(0.85, 0.2, 0.2) if v == 1 else Color(0.15, 0.35, 0.85))
