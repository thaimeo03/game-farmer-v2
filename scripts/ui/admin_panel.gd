class_name AdminPanel
extends Node
## Developer admin tools behind a login (F1). Credentials live in res://config/admin.cfg.
## Disabled in release builds unless the config says enabled_in_release=true.

const CONFIG := "res://config/admin.cfg"

var hud: Hud
var logged_in := false

var _login: PanelContainer
var _user: LineEdit
var _pass: LineEdit
var _error: Label
var _cfg := ConfigFile.new()


func _ready() -> void:
	_cfg.load(CONFIG)
	_build_login()


func available() -> bool:
	return FileAccess.file_exists(CONFIG) and (OS.is_debug_build() or bool(_cfg.get_value("admin", "enabled_in_release", false)))


func toggle() -> void:
	if not available():
		return
	if _login.visible:
		_close_login()
	elif logged_in:
		open_menu()
	elif not GameState.ui_busy:
		_login.show()
		GameState.ui_busy = true
		_user.grab_focus()


func check(user: String, password: String) -> bool:
	return user == str(_cfg.get_value("admin", "username", "")) and password == str(_cfg.get_value("admin", "password", "")) \
		and password != ""


func open_menu() -> void:
	var player := hud.player
	var zone_rows := []
	for z in Database.zones:
		zone_rows.append(["→ " + z.display_name, func() -> void: GameState.travel(z.id, &"" if z.on_bus_route else &"PlayerSpawn"), z.id != GameState.current_zone])
	var rows := [
		{"text": "Tiền", "buttons": [["+10.000 xu", func() -> void: GameState.earn(10000), true],
			["+500 Lượng", _add_gems, true]]},
		{"text": "Cấp hiện tại: %d" % Progression.level, "buttons": [["+1 cấp", _level_up.bind(1), true], ["+5 cấp", _level_up.bind(5), true]]},
		{"text": "Nhận 10 mỗi vật phẩm (hạt, nông sản, thú, nội thất, thời trang...)", "buttons": [["Nhận", _give_all, true]]},
		{"text": "Thời gian & nông trại", "buttons": [["Tua 10 phút", func() -> void: GameState.clock += 600.0, true], ["Làm chín ruộng", _ripen, true]]},
		{"text": "Thời tiết & sự kiện", "buttons": [["Mưa 3 giờ", func() -> void: GameState.rain_until = GameState.clock + 180.0 / GameState.MINUTES_PER_SECOND, true],
			["Tới Trung Thu", _to_festival, true]]},
		{"text": "Thú cưng đang dắt +50 thân thiết", "buttons": [["Thêm", func() -> void: player.add_affection(50), player.active_pet != null]]},
	]
	for i in range(0, zone_rows.size(), 2):
		rows.append({"text": "Đi tới:" if i == 0 else "", "buttons": zone_rows.slice(i, i + 2)})
	rows.append({"text": "Xóa save và chơi lại từ đầu (game sẽ khởi động lại)", "buttons": [["Xóa & chơi lại", _reset_game, true]]})
	rows.append({"text": "Phiên admin", "buttons": [["Đăng xuất", _logout, true]]})
	hud.open_menu("Admin", rows)


func _add_gems() -> void:
	GameState.gems += 500
	GameState.money_changed.emit()


func _logout() -> void:
	logged_in = false
	GameState.toast("Đã đăng xuất admin")


func _level_up(levels: int) -> void:
	for i in levels:
		Progression.add_xp(Progression.xp_to_next() - Progression.xp)


func _give_all() -> void:
	for item: ItemData in Database.items.values():
		GameState.inventory.add(item, 10)
	GameState.toast("Đã nhận 10 mỗi vật phẩm")


## Jumps to 18:00 on the next day 13 of the month (Mid-Autumn starts).
func _to_festival() -> void:
	var day := GameState.day() + 1
	while day % 30 + 1 != 13:
		day += 1
	GameState.clock = (day * 1440 + 18 * 60 - GameState.DAY_START_MINUTE) / GameState.MINUTES_PER_SECOND
	GameState.toast("Đã tới ngày %d — Tết Trung Thu!" % (day + 1))


func _ripen() -> void:
	var grid := get_tree().get_first_node_in_group(&"farm_grid") as FarmGrid
	if grid:
		grid.ripen_all()
		GameState.toast("Ruộng đã chín")
	else:
		GameState.toast("Hãy về Nông Trại trước")


func _reset_game() -> void:
	SaveManager.active = false
	DirAccess.remove_absolute(SaveManager.path)
	OS.set_restart_on_exit(true)
	get_tree().quit()


func _submit(_text := "") -> void:
	if check(_user.text, _pass.text):
		logged_in = true
		_close_login()
		GameState.toast("Đăng nhập admin thành công")
		open_menu()
	else:
		_error.text = "Sai tên đăng nhập hoặc mật khẩu"
		_pass.clear()


func _close_login() -> void:
	_login.hide()
	_pass.clear()
	_error.text = ""
	GameState.ui_busy = false


func _build_login() -> void:
	_login = PanelContainer.new()
	_login.visible = false
	_login.set_anchors_preset(Control.PRESET_CENTER)
	_login.offset_left = -170.0
	_login.offset_right = 170.0
	_login.offset_top = -110.0
	_login.offset_bottom = 110.0
	hud.get_node(^"Root").add_child(_login)
	var box := VBoxContainer.new()
	_login.add_child(box)
	var title := Label.new()
	title.text = "Đăng nhập Admin"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	box.add_child(title)
	_user = LineEdit.new()
	_user.placeholder_text = "Tên đăng nhập"
	box.add_child(_user)
	_pass = LineEdit.new()
	_pass.placeholder_text = "Mật khẩu"
	_pass.secret = true
	_pass.text_submitted.connect(_submit)
	box.add_child(_pass)
	_error = Label.new()
	_error.add_theme_color_override(&"font_color", Color(0.8, 0.15, 0.1))
	box.add_child(_error)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	for spec in [["Đăng nhập", _submit], ["Hủy", _close_login]]:
		var b := Button.new()
		b.text = spec[0]
		b.pressed.connect(spec[1])
		row.add_child(b)
