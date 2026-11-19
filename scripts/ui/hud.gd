class_name Hud
extends CanvasLayer
## Casual HUD: wallet + clock bar, tool quickbar, inventory panel (I/Tab), shop panel,
## toast messages, the fishing timing bar, the race betting panel and the screen fader.

signal timing_bar_done(hit: bool)

var player: Player

var _shop: ShopNpc
var _race: PetRace
var _modal := false ## a panel owns the input (GameState.ui_busy) until closed
var _toast_tween: Tween
var _bar_panel: PanelContainer
var _bar: ColorRect ## the track the marker sweeps over
var _bar_zone: ColorRect
var _bar_marker: ColorRect
var _bar_t := 0.0
var _bar_speed := 1.0
var _bar_time_left := 0.0
var _level_label: Label
var _xp_bar: ProgressBar
var _banner: Label
var _info: Label
var _decor_panel: PanelContainer
var _decor_list: VBoxContainer
var _house: House
var _preview_panel: PanelContainer
var _preview_list: VBoxContainer
var _preview_title: Label
var _preview_root: Node3D
var _preview_builder: Callable
var admin: AdminPanel
var _caro: CaroPanel
var _tracker: QuestTracker
var _emotes: EmoteWheel

@onready var _coins: Label = %Coins
@onready var _gems: Label = %Gems
@onready var _clock: Label = %Clock
@onready var _slots: HBoxContainer = %Slots
@onready var _inventory_panel: Control = %InventoryPanel
@onready var _grid: GridContainer = %Grid
@onready var _shop_panel: Control = %ShopPanel
@onready var _shop_title: Label = %ShopTitle
@onready var _shop_list: VBoxContainer = %ShopList
@onready var _toast: Label = %Toast
@onready var _fader: ColorRect = %Fader


func _ready() -> void:
	add_to_group(&"hud")
	GameState.money_changed.connect(_refresh_money)
	GameState.toasted.connect(toast)
	GameState.shop_requested.connect(open_shop)
	GameState.race_requested.connect(open_race)
	GameState.bus_requested.connect(open_bus)
	Progression.xp_changed.connect(_refresh_level)
	GameState.inventory.changed.connect(_on_inventory_changed)
	%InventoryClose.pressed.connect(close_panels)
	%ShopClose.pressed.connect(close_panels)
	_build_timing_bar()
	_build_level_and_banner()
	_build_decorate_panel()
	_build_preview_panel()
	_caro = CaroPanel.new()
	$Root.add_child(_caro)
	_tracker = QuestTracker.new()
	$Root.add_child(_tracker)
	_emotes = EmoteWheel.new()
	$Root.add_child(_emotes)
	admin = AdminPanel.new()
	admin.hud = self
	add_child(admin)
	_refresh_money()
	_refresh_level()


func bind(p: Player) -> void:
	player = p
	for i in Player.Tool.size():
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(110, 64)
		b.pressed.connect(player.select_tool.bind(i))
		_slots.add_child(b)
	player.tool_changed.connect(_refresh_quickbar)
	_tracker.bind(p)
	_emotes.player = p
	_refresh_quickbar()


func _process(delta: float) -> void:
	_clock.text = GameState.time_text()
	if _preview_panel.visible:
		_preview_root.rotate_y(delta * 0.8)
	if _bar_panel.visible:
		_bar_t += delta * _bar_speed
		_bar_marker.position.x = pingpong(_bar_t, 1.0) * (_bar.custom_minimum_size.x - _bar_marker.size.x)
		_bar_time_left -= delta
		if _bar_time_left <= 0.0:
			_finish_bar(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"admin"):
		admin.toggle()
		get_viewport().set_input_as_handled()
		return
	if _bar_panel.visible and event.is_action_pressed(&"interact"):
		var x := _bar_marker.position.x + _bar_marker.size.x * 0.5
		_finish_bar(x >= _bar_zone.position.x and x <= _bar_zone.position.x + _bar_zone.size.x)
	elif event.is_action_pressed(&"ui_cancel"):
		close_panels()
	elif event.is_action_pressed(&"wardrobe") and not GameState.ui_busy and player:
		open_wardrobe()
	elif event.is_action_pressed(&"journal") and not GameState.ui_busy:
		open_journal()
	elif event.is_action_pressed(&"quest_log") and not GameState.ui_busy:
		open_quests()
	elif event.is_action_pressed(&"emote_wheel") and player:
		if _emotes.visible:
			close_panels()
		elif not GameState.ui_busy:
			_open_modal(_emotes)
	elif event.is_action_pressed(&"inventory") and not _shop_panel.visible:
		_inventory_panel.visible = not _inventory_panel.visible
		_refresh_inventory()
	else:
		return
	get_viewport().set_input_as_handled()


func open_shop(npc: ShopNpc) -> void:
	_open_modal()
	_shop = npc
	_refresh_shop()


func open_race(race: PetRace) -> void:
	var pet: PetData = player.active_pet if player else null
	race.set_guest(pet, player.pet_affection.get(String(pet.id), 0) if pet else 0)
	_open_modal()
	_race = race
	_clear(_shop_list)
	_shop_title.text = "Đua Thú — chọn thú và đặt cược"
	for i in race.racers.size():
		var r: Dictionary = race.racers[i]
		var row := HBoxContainer.new()
		var label := _label("%s  —  thắng x%d" % [r.name, r.payout])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		for bet in [10, 50]:
			var b := Button.new()
			b.text = "Cược %d" % bet
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_place_bet.bind(i, bet))
			row.add_child(b)
		_shop_list.add_child(row)


func open_bus(_stop: BusStop) -> void:
	_open_modal()
	_clear(_shop_list)
	_shop_title.text = "Bảng Tuyến Xe Buýt"
	for zone in Database.zones:
		if zone.id == GameState.current_zone or not zone.on_bus_route:
			continue
		var row := HBoxContainer.new()
		var info := _label("%s
%s" % [zone.display_name, zone.description])
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override(&"font_size", 14)
		row.add_child(info)
		if Progression.is_unlocked(zone):
			var b := Button.new()
			b.text = "Đi • %s" % ("Miễn phí" if zone.ticket_price == 0 else "%d xu" % zone.ticket_price)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(_ride_bus.bind(zone))
			row.add_child(b)
		else:
			row.add_child(_label("Cần cấp %d" % zone.unlock_level))
			row.modulate.a = 0.55
		_shop_list.add_child(row)


## Generic modal list. rows: [{"text": String, "buttons": [[caption, Callable, enabled], ...]}].
## A button closes the menu, then runs its Callable (which may reopen a menu).
func open_menu(title: String, rows: Array) -> void:
	_open_modal()
	_clear(_shop_list)
	_shop_title.text = title
	for r: Dictionary in rows:
		var row := HBoxContainer.new()
		var info := _label(r.text)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(info)
		for spec: Array in r.get("buttons", []):
			var b := Button.new()
			b.text = spec[0]
			b.disabled = not spec[2]
			b.focus_mode = Control.FOCUS_NONE
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var action: Callable = spec[1]
			b.pressed.connect(func() -> void:
				close_panels()
				action.call())
			row.add_child(b)
		_shop_list.add_child(row)
	if rows.is_empty():
		_shop_list.add_child(_label("Không có gì ở đây."))


## Shop with a rotating 3D fitting-room preview. builder() returns open_menu-style rows;
## after any button the rows are rebuilt (the panel stays open).
func open_preview_shop(title: String, builder: Callable, who: Player) -> void:
	_open_modal(_preview_panel)
	_preview_title.text = title
	_preview_builder = builder
	set_preview(who.base_id, who.equipped)
	_refresh_preview_shop()


func set_preview(base_id: String, equipped: Dictionary) -> void:
	for c in _preview_root.get_children():
		c.queue_free()
	var model := Avatar.make_model(base_id)
	_preview_root.add_child(model)
	Avatar.dress(model, equipped)
	var ap := model.find_children("*", "AnimationPlayer", true, false).pop_front() as AnimationPlayer
	if ap and ap.has_animation(&"idle"):
		ap.get_animation(&"idle").loop_mode = Animation.LOOP_LINEAR
		ap.play(&"idle")


## Wardrobe (O): worn / owned accessories, owned pets, and the active pet's care.
func open_wardrobe() -> void:
	var rows := [{"text": "%s  (đổi ở Tiệm Làm Đẹp)" % Avatar.base_name(player.base_id)}]
	for o: OutfitData in Database.outfits.values():
		if GameState.inventory.count(o.item) == 0:
			continue
		var worn: bool = player.equipped.get(o.slot) == o
		rows.append({"text": "%s  [%s]%s" % [o.item.display_name, OutfitData.SLOT_NAMES[o.slot], "  - đang mặc" if worn else ""],
			"buttons": [["Bỏ", player.unequip.bind(o.slot), true]] if worn else [["Mặc", player.equip_outfit.bind(o), true]]})
	for pet: PetData in Database.pets.values():
		if GameState.inventory.count(pet.item) == 0:
			continue
		var active := player.active_pet == pet
		rows.append({"text": "Thú cưng: %s%s" % [pet.display_name, "  - đang dắt" if active else ""],
			"buttons": [["Cất", player.set_active_pet.bind(null), true]] if active else [["Dắt theo", player.set_active_pet.bind(pet), true]]})
	if player.active_pet:
		rows.append_array(player.pet_companion().menu_rows(player))
	for r: Dictionary in rows: # reopen the wardrobe after each action
		for spec: Array in r.get("buttons", []):
			var action: Callable = spec[1]
			spec[1] = func() -> void:
				action.call()
				open_wardrobe()
	open_menu("Tủ Đồ (O)", rows)


func open_caro() -> void:
	_open_modal(_caro)
	_caro.start(_caro.level)


## Fish journal (J): every fish, how many caught and the biggest one.
func open_journal() -> void:
	var rows := []
	var fish := Database.items.values().filter(func(i: ItemData) -> bool: return i.category == ItemData.Category.FISH)
	fish.sort_custom(func(a: ItemData, b: ItemData) -> bool: return a.sell_price < b.sell_price)
	var found := 0
	for f: ItemData in fish:
		var e: Dictionary = GameState.fish_journal.get(String(f.id), {})
		if e.is_empty():
			rows.append({"text": "???  (chưa câu được)"})
		else:
			found += 1
			rows.append({"text": "%s — %d con, lớn nhất %.1f cm" % [f.display_name, int(e.count), float(e.max)]})
	rows.push_front({"text": "Đã khám phá %d/%d loài" % [found, fish.size()]})
	open_menu("Sổ Tay Cá (J)", rows)


## Quest log (L): active quests with progress and rewards, then the neighbors.
func open_quests() -> void:
	var rows := []
	for q in Quests.active_list():
		var kind: String = ["Hướng dẫn", "Hằng ngày", "Hàng xóm", "Sự kiện"][q.kind]
		var line := Quests.progress_text(q.id)
		var head := line if line.begins_with(q.title) else "%s\n• %s" % [q.title, line]
		rows.append({"text": "[%s] %s\nThưởng: %s" % [kind, head, q.reward_text()]})
	var ev := Quests.active_event()
	if ev:
		rows.append({"text": "Đang diễn ra: %s (ngày %d-%d mỗi tháng)" % [ev.title, ev.first_day, ev.last_day]})
	rows.append({"text": "— Hàng xóm —"})
	var m := GameState.minute_of_day()
	for npc in Social.npc_list():
		var w := Social.where(npc, m)
		var zone := Database.zone(StringName(w[0]))
		rows.append({"text": "%s (%s)  %s — đang ở: %s" % [npc.display_name, npc.title, Social.hearts_text(npc.id), zone.display_name if zone else "nhà riêng"]})
	open_menu("Sổ Nhiệm Vụ (L)", rows)


## Letters in the mailbox: read, take the gift.
func open_mail() -> void:
	var rows := []
	for i in Social.mail.size():
		var mail: Dictionary = Social.mail[i]
		var item := Database.item(StringName(mail.item)) if mail.item != "" else null
		var gift := "\nQuà: %d %s" % [int(mail.n), item.display_name] if item and int(mail.n) > 0 else ""
		rows.append({"text": "Từ %s:\n%s%s" % [mail.from, mail.text, gift],
			"buttons": [["Nhận quà" if gift else "Đã đọc", _claim_mail.bind(i), true]]})
	open_menu("Hộp Thư", rows)


func _claim_mail(index: int) -> void:
	Social.claim(index)
	open_mail()


## Small line under the top bar (e.g. house beauty score). Empty hides it.
func show_info(text: String) -> void:
	_info.text = text


func show_decorate(house: House) -> void:
	_house = house
	_inventory_panel.hide()
	_decor_panel.show()
	_refresh_decorate()


func hide_decorate() -> void:
	_decor_panel.hide()
	_house = null


func show_banner(text: String) -> void:
	_banner.text = text


func close_panels() -> void:
	_inventory_panel.hide()
	_shop_panel.hide()
	_preview_panel.hide()
	_caro.hide()
	_emotes.hide()
	_shop = null
	_race = null
	if _modal:
		_modal = false
		GameState.ui_busy = false


## Fishing minigame: a marker sweeps the bar; press interact while it is inside the green zone.
## zone_width is a 0..1 fraction of the bar. Returns true on a hit.
func play_timing_bar(zone_width: float, speed: float, time_limit := 6.0) -> bool:
	_bar_zone.size.x = _bar.custom_minimum_size.x * zone_width
	_bar_zone.position.x = randf_range(0.0, _bar.custom_minimum_size.x - _bar_zone.size.x)
	_bar_t = randf()
	_bar_speed = speed
	_bar_time_left = time_limit
	_bar_panel.show()
	return await timing_bar_done


func _finish_bar(hit: bool) -> void:
	_bar_panel.hide()
	get_viewport().set_input_as_handled()
	timing_bar_done.emit(hit)


func _open_modal(panel: Control = null) -> void:
	_inventory_panel.hide()
	(panel if panel else _shop_panel).show()
	_modal = true
	GameState.ui_busy = true


func _ride_bus(zone: ZoneData) -> void:
	if not GameState.spend(zone.ticket_price):
		return
	close_panels()
	GameState.travel(zone.id)


func _refresh_level() -> void:
	_level_label.text = "Cấp %d" % Progression.level
	_xp_bar.max_value = Progression.xp_to_next()
	_xp_bar.value = Progression.xp
	_xp_bar.tooltip_text = "%d / %d EXP" % [Progression.xp, Progression.xp_to_next()]


func _build_level_and_banner() -> void:
	var top := _coins.get_parent()
	_level_label = _label("Cấp 1")
	top.add_child(_level_label)
	top.move_child(_level_label, 0)
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(110, 14)
	_xp_bar.show_percentage = false
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.45, 0.8, 0.35)
	fill.set_corner_radius_all(6)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.85, 0.75, 0.6)
	bg.set_corner_radius_all(6)
	_xp_bar.add_theme_stylebox_override(&"fill", fill)
	_xp_bar.add_theme_stylebox_override(&"background", bg)
	top.add_child(_xp_bar)
	top.move_child(_xp_bar, 1)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override(&"font_size", 34)
	_banner.add_theme_color_override(&"font_color", Color.WHITE)
	$Root.add_child(_banner)


func _place_bet(index: int, bet: int) -> void:
	var race := _race
	if not GameState.spend(bet):
		return
	close_panels()
	race.start_race(index, bet)


func _build_timing_bar() -> void:
	_bar_panel = PanelContainer.new()
	_bar_panel.visible = false
	_bar_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar_panel.offset_left = -240.0
	_bar_panel.offset_right = 240.0
	_bar_panel.offset_top = -210.0
	_bar_panel.offset_bottom = -120.0
	$Root.add_child(_bar_panel)
	var box := VBoxContainer.new()
	_bar_panel.add_child(box)
	var title := _label("Bấm E khi kim nằm trong vùng xanh!")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_bar = ColorRect.new()
	_bar.color = Color(0.45, 0.3, 0.2)
	_bar.custom_minimum_size = Vector2(440, 34)
	box.add_child(_bar)
	_bar_zone = ColorRect.new()
	_bar_zone.color = Color(0.4, 0.85, 0.35)
	_bar_zone.size = Vector2(100, 34)
	_bar.add_child(_bar_zone)
	_bar_marker = ColorRect.new()
	_bar_marker.color = Color(1, 0.95, 0.4)
	_bar_marker.size = Vector2(8, 34)
	_bar.add_child(_bar_marker)



func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func fade(to_alpha: float, time := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(_fader, "color:a", to_alpha, time)
	await tw.finished


func _on_inventory_changed() -> void:
	if player:
		_refresh_quickbar()
	if _inventory_panel.visible:
		_refresh_inventory()
	if _shop_panel.visible and _shop:
		_refresh_shop()
	if _decor_panel.visible:
		_refresh_decorate()


func _refresh_money() -> void:
	_coins.text = "Xu: %d" % GameState.coins
	_gems.text = "Lượng: %d" % GameState.gems


func _refresh_quickbar() -> void:
	for i in _slots.get_child_count():
		var b: Button = _slots.get_child(i)
		b.set_pressed_no_signal(i == player.tool)
		b.text = "%d. %s" % [i + 1, player.tool_label(i)]
		var s := player.current_seed() if i == Player.Tool.SEED else null
		b.icon = s.get_icon() if s else null


func _refresh_inventory() -> void:
	_clear(_grid)
	for item in GameState.inventory.items():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(76, 76)
		b.icon = item.get_icon()
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.text = "%s\nx%d" % [item.display_name, GameState.inventory.count(item)]
		b.tooltip_text = "%s\nBán: %d xu" % [item.description, item.sell_price]
		b.add_theme_font_size_override(&"font_size", 12)
		_grid.add_child(b)
	if _grid.get_child_count() == 0:
		_grid.add_child(_label("Túi trống"))


func _refresh_shop() -> void:
	_clear(_shop_list)
	_shop_title.text = _shop.title
	if _shop.mode == ShopNpc.Mode.BUY:
		for item in _shop.stock:
			_shop_row(item, "%s  —  %d xu" % [item.display_name, item.buy_price], {"Mua 1": 1, "Mua 5": 5}, GameState.buy)
	else:
		for item in GameState.inventory.items():
			var n := GameState.inventory.count(item)
			if item.sell_price > 0:
				_shop_row(item, "%s x%d  —  %d xu/cái" % [item.display_name, n, item.sell_price], {"Bán 1": 1, "Bán hết": n}, GameState.sell)
	if _shop_list.get_child_count() == 0:
		_shop_list.add_child(_label("Không có gì để bán"))


func _shop_row(item: ItemData, text: String, buttons: Dictionary, action: Callable) -> void:
	var row := HBoxContainer.new()
	var icon := TextureRect.new()
	icon.texture = item.get_icon()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(icon)
	var label := _label(text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	for caption: String in buttons:
		var b := Button.new()
		b.text = caption
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(action.bind(item, buttons[caption]))
		row.add_child(b)
	_shop_list.add_child(row)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _build_decorate_panel() -> void:
	_info = Label.new()
	_info.position = Vector2(16, 64)
	_info.add_theme_color_override(&"font_outline_color", Color.WHITE)
	_info.add_theme_constant_override(&"outline_size", 6)
	$Root.add_child(_info)
	_decor_panel = PanelContainer.new()
	_decor_panel.visible = false
	_decor_panel.position = Vector2(16, 100)
	_decor_panel.custom_minimum_size = Vector2(250, 0)
	$Root.add_child(_decor_panel)
	var box := VBoxContainer.new()
	_decor_panel.add_child(box)
	var title := _label("Trang trí nhà")
	title.add_theme_font_size_override(&"font_size", 20)
	box.add_child(title)
	box.add_child(_label("Chọn đồ rồi click lên sàn.
Click đồ đã đặt để cất. R: xoay"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_decor_list = VBoxContainer.new()
	_decor_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_decor_list)
	var row := HBoxContainer.new()
	box.add_child(row)
	for spec in [["Xoay", func() -> void: _house.rotate_selection()], ["Sàn ▶", func() -> void: _house.next_floor()],
			["Tường ▶", func() -> void: _house.next_wall()], ["Xong", func() -> void: _house.set_decorating(false)]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		row.add_child(b)


func _refresh_decorate() -> void:
	_clear(_decor_list)
	for item in GameState.inventory.items(ItemData.Category.FURNITURE):
		var data: FurnitureData = Database.furniture.get(item.id)
		if not data:
			continue
		var b := Button.new()
		b.text = "%s x%d" % [item.display_name, GameState.inventory.count(item)]
		b.toggle_mode = true
		b.button_pressed = _house != null and _house.selected == data
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			_house.select(data)
			_refresh_decorate())
		_decor_list.add_child(b)
	if _decor_list.get_child_count() == 0:
		_decor_list.add_child(_label("Túi chưa có nội thất.
Mua ở Phố Chợ."))


func _refresh_preview_shop() -> void:
	_clear(_preview_list)
	for r: Dictionary in _preview_builder.call():
		var row := HBoxContainer.new()
		var info := _label(r.text)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override(&"font_size", 14)
		row.add_child(info)
		for spec: Array in r.get("buttons", []):
			var b := Button.new()
			b.text = spec[0]
			b.disabled = not spec[2]
			b.focus_mode = Control.FOCUS_NONE
			var action: Callable = spec[1]
			var is_try: bool = spec[0] == "Thử"
			b.pressed.connect(func() -> void:
				action.call()
				if not is_try:
					_refresh_preview_shop()
					set_preview(player.base_id, player.equipped))
			row.add_child(b)
		_preview_list.add_child(row)


func _build_preview_panel() -> void:
	_preview_panel = PanelContainer.new()
	_preview_panel.visible = false
	_preview_panel.set_anchors_preset(Control.PRESET_CENTER)
	_preview_panel.offset_left = -380.0
	_preview_panel.offset_right = 380.0
	_preview_panel.offset_top = -230.0
	_preview_panel.offset_bottom = 230.0
	$Root.add_child(_preview_panel)
	var outer := VBoxContainer.new()
	_preview_panel.add_child(outer)
	_preview_title = _label("")
	_preview_title.add_theme_font_size_override(&"font_size", 22)
	_preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_preview_title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_preview_list = VBoxContainer.new()
	_preview_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_preview_list)
	# fitting room: its own 3D world inside a SubViewport
	var frame := SubViewportContainer.new()
	frame.stretch = true
	frame.custom_minimum_size = Vector2(280, 360)
	body.add_child(frame)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	frame.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 25, 0)
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.1, 3.9), Vector3(0, 0.85, 0))
	_preview_root = Node3D.new()
	vp.add_child(_preview_root)
	var close := Button.new()
	close.text = "Đóng"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_panels)
	outer.add_child(close)
