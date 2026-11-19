extends Node
## Autoload "Social": friendship with the neighbors, the mailbox, and the daily farm visit.
## Saved under "social".

signal friendship_changed(npc_id: StringName)
signal mail_changed

const HEART := 20 ## points per heart
const MAX_HEARTS := 5
const VISIT_MINUTE := 10 * 60 ## the day's visitor comes to the farm 10:00-11:00
const VISIT_LENGTH := 60
const VISIT_WATER := 4 ## dry plots the visitor waters

var points := {} ## npc id (String) -> int
var mail: Array = [] ## {"from": String, "text": String, "item": String, "n": int}


func _ready() -> void:
	var saved = SaveManager.register(&"social", self)
	if saved:
		load_save(saved)
	else:
		send_mail("Ông Bảy (Bưu điện)", "Chào mừng bạn đến làng! Đây là chút quà nhỏ để bắt đầu. Có thư mới thì xem ở hộp thư trước nhà hoặc Bưu điện Phố Chợ nhé.", &"seed_tomato", 3)


func hearts(id: StringName) -> int:
	return mini(MAX_HEARTS, int(points.get(String(id), 0)) / HEART)


func hearts_text(id: StringName) -> String:
	var h := hearts(id)
	return "♥".repeat(h) + "♡".repeat(MAX_HEARTS - h)


func add_points(npc: NpcData, amount: int) -> void:
	var before := hearts(npc.id)
	points[String(npc.id)] = clampi(int(points.get(String(npc.id), 0)) + amount, 0, HEART * MAX_HEARTS)
	var after := hearts(npc.id)
	if after > before:
		GameState.toast("%s thân với bạn hơn rồi! %s" % [npc.display_name, hearts_text(npc.id)])
		if after == 3 and npc.quest:
			send_mail(npc.display_name, "Mình có chuyện muốn nhờ bạn. Gặp mình nói chuyện nhé!", &"", 0)
		elif after == MAX_HEARTS:
			send_mail(npc.display_name, "Cảm ơn vì luôn là người bạn tốt. Tặng bạn món này!", &"spin_ticket", 2)
	friendship_changed.emit(npc.id)


## Small talk: returns the line. The first chat of the day earns friendship.
func talk(npc: NpcData) -> String:
	if GameState.daily_use("talk_" + String(npc.id), 1, true):
		add_points(npc, 2)
		Quests.notify(&"talk", npc.id)
	return npc.line_for(hearts(npc.id))


## Returns the neighbor's reaction. One gift per neighbor per day.
func gift(npc: NpcData, item: ItemData) -> String:
	if GameState.daily_count("gift_" + String(npc.id)) > 0:
		return "Hôm nay bạn tặng mình rồi, để mai nhé!"
	if not GameState.inventory.remove(item):
		return ""
	GameState.daily_use("gift_" + String(npc.id), 1, true)
	Quests.notify(&"gift", item.id)
	if item.id in npc.likes:
		add_points(npc, 8)
		return "Ôi, %s! Mình thích lắm, cảm ơn bạn!" % item.display_name
	if item.id in npc.dislikes:
		add_points(npc, -3)
		return "Ừm... cảm ơn. (có vẻ không thích lắm)"
	add_points(npc, 3)
	return "Cảm ơn bạn nhé!"


## Emoting at a neighbor: a little friendship once a day.
func greet(npc: NpcData) -> void:
	if GameState.daily_use("emote_" + String(npc.id), 1, true):
		add_points(npc, 1)


func send_mail(from: String, text: String, item: StringName = &"", n := 0) -> void:
	mail.append({"from": from, "text": text, "item": String(item), "n": n})
	GameState.toast("Bạn có thư mới từ %s" % from)
	mail_changed.emit()


## Takes the letter's gift (if any) and removes the letter.
func claim(index: int) -> void:
	var m: Dictionary = mail[index]
	var item := Database.item(StringName(m.item)) if m.item != "" else null
	if item and int(m.n) > 0:
		GameState.inventory.add(item, int(m.n))
		GameState.toast("Nhận %d %s" % [int(m.n), item.display_name])
	mail.remove_at(index)
	Quests.notify(&"mail")
	mail_changed.emit()


## Who visits the farm today (one neighbor per day, by turns).
func visitor() -> NpcData:
	var list := npc_list()
	return list[GameState.day() % list.size()] if list.size() > 0 else null


func npc_list() -> Array[NpcData]:
	var list: Array[NpcData] = []
	list.assign(Database.npcs.values())
	list.sort_custom(func(a: NpcData, b: NpcData) -> bool: return a.id < b.id)
	return list


## [zone_id, anchor] for `npc` now, including the daily farm visit.
func where(npc: NpcData, minute: float) -> PackedStringArray:
	if npc == visitor() and minute >= VISIT_MINUTE and minute < VISIT_MINUTE + VISIT_LENGTH:
		return PackedStringArray(["my_farm", "Mailbox"])
	return npc.where(minute)


## Runs the day's visit once it is due: waters a few dry plots (if the farm is loaded) and
## leaves a present in the mailbox. `farm` may be null.
func run_visit(farm: FarmGrid) -> bool:
	var npc := visitor()
	if npc == null or GameState.minute_of_day() < VISIT_MINUTE or not GameState.daily_use("farm_visit", 1, true):
		return false
	var watered := farm.water_dry(VISIT_WATER) if farm else 0
	var gift_id: StringName = [&"egg", &"milk", &"fertilizer", &"pet_treat", &"bait"][GameState.day() % 5]
	send_mail(npc.display_name, "Mình ghé nông trại của bạn%s. Để lại chút quà nhé!" % (", tưới giúp %d ô đất" % watered if watered else ""), gift_id, 2)
	return true


func to_save() -> Dictionary:
	return {"points": points, "mail": mail}


func load_save(d: Dictionary) -> void:
	points = d.get("points", {})
	mail = d.get("mail", [])
	mail_changed.emit()
