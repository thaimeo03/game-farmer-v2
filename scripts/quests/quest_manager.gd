extends Node
## Autoload "Quests": tutorial chain, 3 daily quests, NPC quests and the seasonal event.
## Game code reports what the player did with notify(action, what); matching steps advance.
## Saved under "quests".

signal changed
signal completed(quest: QuestData)

const TUTORIAL_START := &"tut_1"
const DAILY_COUNT := 3
## Daily templates: [do, count, text, coins, min_level]
const DAILY_POOL := [
	[&"water", 6, "Tưới 6 ô đất", 40, 1],
	[&"harvest", 5, "Thu hoạch 5 lần", 50, 1],
	[&"sell", 5, "Bán 5 món đồ", 40, 1],
	[&"fish", 2, "Câu được 2 con cá", 50, 1],
	[&"talk", 2, "Trò chuyện với 2 hàng xóm", 30, 1],
	[&"gift", 1, "Tặng quà cho 1 hàng xóm", 40, 1],
	[&"emote", 2, "Chào mọi người bằng 2 biểu cảm", 20, 1],
	[&"play", 1, "Chơi 1 trò ở Công Viên", 40, 2],
	[&"collect", 3, "Thu 3 sản phẩm từ vật nuôi", 50, 3],
	[&"craft", 2, "Chế biến 2 món", 60, 3],
	[&"order", 1, "Giao 1 đơn hàng xe tải", 60, 2],
]

var enabled := true ## tests switch this off so rewards don't disturb other checks
var active := {} ## quest id (String) -> {"step": int, "n": int}
var done := {} ## quest id (String) -> day it was completed
var event_round := -1 ## which month's event the event quest belongs to
var _daily := {} ## today's generated QuestData by id
var _daily_day := -1


func _ready() -> void:
	var saved = SaveManager.register(&"quests", self)
	if saved:
		load_save(saved)
	else:
		start(TUTORIAL_START, true)


func _process(_delta: float) -> void:
	if enabled and Engine.get_process_frames() % 30 == 0:
		_refresh_day()


func quest(id: StringName) -> QuestData:
	_refresh_day()
	return Database.quests.get(id, _daily.get(id))


func is_active(id: StringName) -> bool:
	return active.has(String(id))


func is_done(id: StringName) -> bool:
	return done.has(String(id))


func start(id: StringName, quiet := false) -> void:
	var q := quest(id)
	if q == null or is_active(id) or is_done(id):
		return
	active[String(id)] = {"step": 0, "n": 0}
	if not quiet:
		GameState.toast("Nhiệm vụ mới: %s" % q.title)
	changed.emit()


## Report an action. `what` filters steps that name a specific item / zone / neighbor.
func notify(action: StringName, what: StringName = &"", amount := 1) -> void:
	if not enabled:
		return
	_refresh_day()
	var finished: Array[String] = []
	for id: String in active.keys():
		var q := quest(StringName(id))
		var state: Dictionary = active[id]
		if q == null or state.step >= q.steps.size():
			continue
		var step: Dictionary = q.steps[state.step]
		if StringName(step.get("do", "")) != action or (step.get("what", "") != "" and StringName(step.what) != what):
			continue
		state.n += amount
		if state.n >= int(step.get("count", 1)):
			state.step += 1
			state.n = 0
			if state.step >= q.steps.size():
				finished.append(id)
			elif q.kind == QuestData.Kind.TUTORIAL:
				GameState.toast("Tiếp theo: %s" % q.steps[state.step].text)
	for id in finished:
		_complete(id)
	changed.emit()


func current_step(id: StringName) -> Dictionary:
	var q := quest(id)
	var state: Dictionary = active.get(String(id), {})
	if q == null or state.is_empty() or state.step >= q.steps.size():
		return {}
	return q.steps[state.step]


func progress_text(id: StringName) -> String:
	var step := current_step(id)
	if step.is_empty():
		return ""
	var count := int(step.get("count", 1))
	var n: int = active[String(id)].n
	return "%s%s" % [step.text, "  (%d/%d)" % [n, count] if count > 1 else ""]


## The quest the HUD tracker and guide arrow follow: tutorial > event > NPC > daily.
func tracked() -> StringName:
	var best := &""
	var best_rank := 99
	for id: String in active:
		var q := quest(StringName(id))
		if q == null:
			continue
		var rank: int = [0, 3, 2, 1][q.kind]
		if rank < best_rank:
			best_rank = rank
			best = StringName(id)
	return best


## Active quests in tracker order.
func active_list() -> Array[QuestData]:
	var out: Array[QuestData] = []
	for id: String in active:
		var q := quest(StringName(id))
		if q:
			out.append(q)
	out.sort_custom(func(a: QuestData, b: QuestData) -> bool: return [0, 3, 2, 1][a.kind] < [0, 3, 2, 1][b.kind])
	return out


func active_event() -> EventData:
	for e: EventData in Database.events.values():
		if e.is_active(GameState.day_of_month()):
			return e
	return null


func to_save() -> Dictionary:
	return {"active": active, "done": done, "event_round": event_round}


func load_save(d: Dictionary) -> void:
	active = d.get("active", {})
	done = d.get("done", {})
	event_round = int(d.get("event_round", -1))
	_daily_day = -1
	_refresh_day()
	changed.emit()


func _complete(id: String) -> void:
	var q := quest(StringName(id))
	active.erase(id)
	done[id] = GameState.day()
	GameState.earn(q.reward_coins)
	if q.reward_gems:
		GameState.gems += q.reward_gems
		GameState.money_changed.emit()
	for item_id: StringName in q.reward_items:
		GameState.inventory.add(Database.item(item_id), int(q.reward_items[item_id]))
	if q.reward_xp:
		Progression.add_xp(q.reward_xp)
	var reward := q.reward_text()
	GameState.toast("Hoàn thành: %s!%s" % [q.title, "  +" + reward if reward else ""])
	completed.emit(q)
	if q.next:
		start(q.next)


## New day: replace yesterday's dailies, forget old daily completions, start/stop the event quest.
func _refresh_day() -> void:
	var today := GameState.day()
	if today == _daily_day:
		return
	_daily_day = today
	_daily = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today * 31 + 7)
	var pool := DAILY_POOL.filter(func(t: Array) -> bool: return Progression.level >= t[4])
	for i in DAILY_COUNT:
		var t: Array = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var q := QuestData.new()
		q.id = StringName("daily_%d_%d" % [today, i])
		q.title = t[2]
		q.kind = QuestData.Kind.DAILY
		q.steps = [{"do": String(t[0]), "count": t[1], "text": t[2]}]
		q.reward_coins = t[3]
		q.reward_xp = 10
		_daily[q.id] = q
	for id: String in active.keys():
		if id.begins_with("daily_") and not _daily.has(StringName(id)):
			active.erase(id)
	for id: String in done.keys():
		if id.begins_with("daily_") and int(done[id]) != today:
			done.erase(id)
	for id: StringName in _daily:
		if not is_done(id) and not is_active(id):
			active[String(id)] = {"step": 0, "n": 0}
	var ev := active_event()
	var event_quest := ev.quest.id if ev and ev.quest else &""
	for e: EventData in Database.events.values(): # an ended event takes its quest with it
		if e.quest and e != ev:
			active.erase(String(e.quest.id))
	if ev and event_round != today / 30:
		event_round = today / 30
		if event_quest:
			done.erase(String(event_quest))
			start(event_quest, true)
		Social.send_mail(ev.title, ev.letter, &"", 0)
	changed.emit()
