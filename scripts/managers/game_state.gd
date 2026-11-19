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
	toast("Đã mua %d %s" % [amount, item.display_name])
	return true


func sell(item: ItemData, amount := 1) -> bool:
	if item.sell_price <= 0 or not inventory.remove(item, amount):
		return false
	earn(item.sell_price * amount)
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


## Uses one of today's `limit` tries; false (with a toast) when none are left.
func daily_use(key: String, limit: int) -> bool:
	var n := daily_count(key)
	if n >= limit:
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


func time_text() -> String:
	var m := DAY_START_MINUTE + int(clock * MINUTES_PER_SECOND)
	return "Ngày %d  %02d:%02d" % [m / 1440 + 1, m / 60 % 24, m % 60]


func toast(text: String) -> void:
	toasted.emit(text)


## Empty spawn = by bus (arrive at the BusStop); otherwise walk in to that Marker3D (doors).
func travel(zone_id: StringName, spawn: StringName = &"") -> void:
	travel_requested.emit(zone_id, spawn)
