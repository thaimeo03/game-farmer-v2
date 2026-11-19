class_name PostOffice
extends InteractZone
## Mailbox (farm) or post office counter (Phố Chợ): read letters and take their gifts.
## The counter can also post a gift to any neighbor for a small fee.

const POSTAGE := 5

@export var counter := false


func _ready() -> void:
	super()
	Social.mail_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var n := Social.mail.size()
	var what := "Bưu điện" if counter else "Hộp thư"
	set_prompt("[E] %s%s" % [what, " (%d thư mới)" % n if n else ""])


func interact(_player: Player) -> void:
	if counter:
		hud().open_menu("Bưu Điện", [
			{"text": "Hộp thư: %d thư" % Social.mail.size(), "buttons": [["Xem thư", hud().open_mail, true]]},
			{"text": "Gửi quà cho hàng xóm (%d xu/lần, tính là quà hôm nay)" % POSTAGE, "buttons": [["Gửi quà", _pick_neighbor, true]]},
		])
	else:
		hud().open_mail()


func _pick_neighbor() -> void:
	var rows := []
	for npc in Social.npc_list():
		rows.append({"text": "%s — %s  %s" % [npc.display_name, npc.title, Social.hearts_text(npc.id)],
			"buttons": [["Chọn", _pick_item.bind(npc), GameState.daily_count("gift_" + String(npc.id)) == 0]]})
	hud().open_menu("Gửi quà cho ai?", rows)


func _pick_item(npc: NpcData) -> void:
	var rows := []
	for item: ItemData in GameState.inventory.items():
		if item.category in [ItemData.Category.TOOL, ItemData.Category.OUTFIT, ItemData.Category.PET, ItemData.Category.FURNITURE]:
			continue
		rows.append({"text": "%s x%d" % [item.display_name, GameState.inventory.count(item)],
			"buttons": [["Gửi", _send.bind(npc, item), true]]})
	hud().open_menu("Gửi quà cho %s" % npc.display_name, rows)


func _send(npc: NpcData, item: ItemData) -> void:
	if not GameState.spend(POSTAGE):
		return
	var reply := Social.gift(npc, item)
	if reply:
		Social.send_mail(npc.display_name, "Mình nhận được quà rồi! %s" % reply)
