extends Node
## Autoload "GameState": wallet, inventory, world clock, and the small event bus
## that lets world objects (portals, NPCs) talk to Main and the HUD.

signal money_changed
signal toasted(text: String)
signal travel_requested(zone_id: StringName, spawn: StringName)
signal bus_requested(stop: BusStop)
signal shop_requested(npc: ShopNpc)
signal race_requested(race: PetRace)

const MINUTES_PER_SECOND := 1.0 ## 1 real second = 1 in-game minute (24-minute day)
const DAY_START_MINUTE := 6 * 60

var coins := 100 ## Xu
var gems := 0 ## Lượng (premium, no source yet)
var clock := 0.0 ## seconds of play; crops grow against this so they keep growing while you are in the city
var inventory := Inventory.new()
var current_zone: StringName = &"my_farm"
var fish_journal := {} ## fish id (String) -> {"count": int, "max": float cm}
var daily := {} ## activity key -> {"day": int, "n": int} for per-day limits
var rain_until := 0.0 ## admin "rain now": clock value until which it rains
var ui_busy := false ## true while a modal panel or a level transition owns the input


func _ready() -> void:
	inventory.add(preload("res://resources/items/seed_carrot.tres"), 5)


func _process(delta: float) -> void:
	clock += delta


func buy(item: ItemData, amount := 1) -> bool:
	var cost := item.buy_price * amount
	if item.buy_price <= 0 or amount <= 0:
		return false
	if not spend(cost):
		return false
	inventory.add(item, amount)
	Quests.notify(&"buy", item.id, amount)
	toast("Đã mua %d %s" % [amount, item.display_name])
	return true


func sell(item: ItemData, amount := 1) -> bool:
	if item.sell_price <= 0 or not inventory.remove(item, amount):
		return false
	earn(item.sell_price * amount)
	Quests.notify(&"sell", item.id, amount)
	toast("+%d xu" % (item.sell_price * amount))
	return true


func spend(amount: int) -> bool:
	if amount < 0 or coins < amount:
		toast("Không đủ xu!")
		return false
	coins -= amount
	money_changed.emit()
	return true


func spend_gems(amount: int) -> bool:
	if amount < 0 or gems < amount:
		toast("Không đủ Lượng!")
		return false
	gems -= amount
	money_changed.emit()
	return true


func earn(amount: int) -> void:
	coins += amount
	money_changed.emit()


func day() -> int:
	return (DAY_START_MINUTE + int(clock * MINUTES_PER_SECOND)) / 1440


## How many times `key` was used today.
func daily_count(key: String) -> int:
	var d: Dictionary = daily.get(key, {})
	return int(d.get("n", 0)) if int(d.get("day", -1)) == day() else 0


## Uses one of today's `limit` tries; false (with a toast unless quiet) when none are left.
func daily_use(key: String, limit: int, quiet := false) -> bool:
	var n := daily_count(key)
	if n >= limit:
		if not quiet:
			toast("Hết lượt hôm nay, mai quay lại nhé!")
		return false
	daily[key] = {"day": day(), "n": n + 1}
	return true


## Rolls a size for a caught fish and updates the journal. Returns [size_cm, is_record].
func record_fish(item: ItemData) -> Array:
	var size := snappedf(randf_range(item.size_range.x, item.size_range.y), 0.1) if item.size_range != Vector2.ZERO else 0.0
	var entry: Dictionary = fish_journal.get(String(item.id), {"count": 0, "max": 0.0})
	var record := size > float(entry.max)
	fish_journal[String(item.id)] = {"count": int(entry.count) + 1, "max": maxf(size, float(entry.max))}
	return [size, record and int(entry.count) > 0]


## Minute of the in-game day (0..1440), fractional.
func minute_of_day() -> float:
	return fmod(DAY_START_MINUTE + clock * MINUTES_PER_SECOND, 1440.0)


func hour() -> int:
	return int(minute_of_day()) / 60


## Day of the 30-day month, 1..30 (seasonal events use it).
func day_of_month() -> int:
	return day() % 30 + 1


## Today's rain as [start, end) minutes, or (-1, -1) for a dry day. Deterministic per day so
## it needs no saving; about a third of days rain for 1.5-3.5 hours. Day 1 is always sunny.
static func rain_window(d: int) -> Vector2i:
	if d == 0:
		return Vector2i(-1, -1)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(d * 7919 + 13)
	if rng.randf() > 0.35:
		return Vector2i(-1, -1)
	var start := rng.randi_range(8, 15) * 60
	return Vector2i(start, start + rng.randi_range(90, 210))


func is_raining() -> bool:
	if clock < rain_until:
		return true
	var w := rain_window(day())
	var m := minute_of_day()
	return m >= w.x and m < w.y


## The hour after a rain stops shows a rainbow.
func has_rainbow() -> bool:
	if rain_until > 0.0 and clock >= rain_until and clock < rain_until + 60.0 / MINUTES_PER_SECOND:
		return true
	var w := rain_window(day())
	var m := minute_of_day()
	return w.x >= 0 and m >= w.y and m < w.y + 60


func time_text() -> String:
	var m := DAY_START_MINUTE + int(clock * MINUTES_PER_SECOND)
	return "Ngày %d  %02d:%02d  %s" % [m / 1440 + 1, m / 60 % 24, m % 60, "Mưa" if is_raining() else ("Đêm" if m / 60 % 24 >= 19 or m / 60 % 24 < 5 else "Nắng")]


func toast(text: String) -> void:
	toasted.emit(text)


## Empty spawn = by bus (arrive at the BusStop); otherwise walk in to that Marker3D (doors).
func travel(zone_id: StringName, spawn: StringName = &"") -> void:
	travel_requested.emit(zone_id, spawn)
