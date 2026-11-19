extends Node
## Run: godot --headless --path . tests/run_tests.tscn   (exit code 1 on failure)
## A scene (not a -s script) so autoloads like GameState are available.

var _fails := 0


func _ready() -> void:
	await get_tree().process_frame
	await test_farm()
	test_economy()
	test_minigames()
	await test_world()
	await test_farm_plus()
	await test_house()
	await test_fashion()
	await test_camera()
	print("FAILURES: %d" % _fails if _fails else "ALL PASS")
	get_tree().quit(1 if _fails else 0)


func test_farm() -> void:
	var farm: Node = load("res://scenes/zones/my_farm.tscn").instantiate()
	add_child(farm)
	await get_tree().process_frame
	var crop: CropData = load("res://resources/crops/carrot.tres")
	var grid: FarmGrid = farm.get_node(^"FarmGrid")

	# Grid: origin (-3.6, 0, -2.4), 6x4 cells of 1.2
	_check(grid.get_plot_at(Vector3(-3.0, 0, -2.0)) == grid.get_plot(Vector2i(0, 0)), "cell (0,0) lookup")
	_check(grid.get_plot_at(Vector3(3.5, 0, 2.3)) == grid.get_plot(Vector2i(5, 3)), "cell (5,3) lookup")
	_check(grid.get_plot_at(Vector3(-3.7, 0, 0)) == null, "outside grid -> null")

	var plot := grid.get_plot(Vector2i(2, 1))
	var got: Array[CropData] = []
	grid.crop_harvested.connect(func(_p: FarmPlot, c: CropData) -> void: got.append(c))

	_check(plot.can(&"till") and not plot.can(&"plant") and not plot.can(&"water"), "fresh plot only tillable")
	plot.perform(&"till")
	_check(plot.can(&"plant"), "tilled -> plantable")
	plot.perform(&"plant", crop)
	GameState.clock += 100.0
	plot._process(0.0)
	_check(plot.stage == 0, "no growth while dry")
	_check(plot.can(&"water"), "planted -> waterable")
	plot.problem_chance = 0.0
	for d in crop.stage_durations:
		_check(not plot.can(&"harvest"), "not harvestable before mature")
		plot.perform(&"water")
		GameState.clock += d
		plot._process(0.0)
		_check(not plot.is_watered, "soil dries after each stage")
		GameState.clock += 100.0
		var before := plot.stage
		plot._process(0.0)
		_check(plot.stage == before, "a dry stage does not grow")
	_check(crop.stage_at(0.0) == 0 and crop.stage_at(1e6) == crop.stage_durations.size(), "stage_at bounds")
	_check(crop.produce != null, "crop has produce item")
	_check(plot.can(&"harvest"), "mature -> harvestable")
	plot.perform(&"harvest")
	_check(got == [crop], "harvest emits crop via grid")
	_check(plot.state == FarmPlot.State.NORMAL and plot.crop == null and not plot.is_watered, "plot reset")

	_check(InputMap.has_action(&"interact") and InputMap.action_get_events(&"interact").size() == 3, "input map loaded")

	farm.free()


func test_economy() -> void:
	var gs := GameState
	var seed_item: ItemData = load("res://resources/items/seed_tomato.tres")
	var tomato: ItemData = load("res://resources/items/tomato.tres")
	var inv: Inventory = gs.inventory

	_check(inv.count(load("res://resources/items/seed_carrot.tres")) == 5 and gs.coins == 100, "starting kit")
	_check(seed_item.crop.produce == tomato, "seed -> crop -> produce chain")

	_check(gs.buy(seed_item, 3) and gs.coins == 70 and inv.count(seed_item) == 3, "buy 3 seeds")
	_check(not gs.buy(seed_item, 100) and gs.coins == 70, "cannot overspend")
	_check(not gs.buy(tomato, 1), "produce not buyable")

	inv.add(tomato, 2)
	_check(inv.items(ItemData.Category.PRODUCE) == [tomato], "category filter")
	_check(not gs.sell(tomato, 3) and gs.coins == 70, "cannot sell more than owned")
	_check(gs.sell(tomato, 2) and gs.coins == 130 and inv.count(tomato) == 0, "sell 2 tomatoes")
	_check(not tomato in inv.items(), "empty stack removed")

	var city: Node = load("res://scenes/zones/market_town.tscn").instantiate()
	var shop: ShopNpc = city.get_node(^"SeedShop")
	_check(shop.stock.size() == 4 and shop.stock[0] is ItemData, "seed shop stock loaded (3 seeds + bait)")
	city.free()

	gs.clock = 0.0
	_check(gs.time_text() == "Ngày 1  06:00", "clock start")
	gs.clock = 18.0 * 60.0 / gs.MINUTES_PER_SECOND
	_check(gs.time_text() == "Ngày 2  00:00", "clock rolls day")



func test_minigames() -> void:
	var race: PetRace = load("res://scenes/minigames/pet_race.tscn").instantiate()
	add_child(race)
	_check(race.racers.size() == 5 and race.racers[0].node is Node3D, "race spawns 5 racers")
	race.racing = true
	for i in 600:
		race._process(0.05)
		if not race.racing:
			break
	_check(not race.racing and race._winner >= 0, "race always finishes with a winner")
	_check(race.racers[race._winner].node.position.z <= -race.track_length, "winner crossed the line")
	race.queue_free()

	var spot := FishingSpot.new()
	var counts := [0, 0, 0, 0, 0]
	for i in 4000:
		counts[spot._pick()] += 1
	_check(counts.min() > 0, "every catch can happen")
	_check(counts[2] == counts.min(), "gold fish is the rarest catch")
	_check(spot.catches[2].sell_price > spot.catches[0].sell_price, "rare fish sells for more")
	spot.free()


func test_world() -> void:
	# content database
	_check(Database.item(&"fish_gold") != null and Database.crop(&"tomato") != null, "database finds items and crops by id")
	_check(Database.zones.size() == 7 and Database.zones[0].id == &"my_farm", "7 zones, ordered")
	_check(Database.zones.filter(func(z: ZoneData) -> bool: return z.on_bus_route).size() == 6, "6 zones on the bus route")
	for z in Database.zones.filter(func(z: ZoneData) -> bool: return z.on_bus_route):
		var root: Node = load(z.scene_path).instantiate()
		_check(root.find_child("BusStop", true, false) is BusStop, "zone %s has a BusStop" % z.id)
		root.free()

	# progression: level-ups unlock zones
	Progression.level = 1
	Progression.xp = 0
	var beach := Database.zone(&"sunny_beach")
	_check(not Progression.is_unlocked(beach), "beach locked at level 1")
	Progression.add_xp(60 + 120)
	_check(Progression.level == 3 and Progression.xp == 0, "XP rolls over into levels")
	_check(Progression.is_unlocked(beach), "beach unlocked at level 3")

	# save -> mutate -> load round trip, including a growing plot and offline time
	SaveManager.path = "user://test_saves/slot_test.json"
	var farm: Node = load("res://scenes/zones/my_farm.tscn").instantiate()
	add_child(farm)
	await get_tree().process_frame
	var grid: FarmGrid = farm.get_node(^"FarmGrid")
	var plot := grid.get_plot(Vector2i(1, 1))
	plot.perform(&"till")
	plot.perform(&"plant", Database.crop(&"pumpkin"))
	plot.problem_chance = 0.0
	plot.perform(&"water")
	GameState.coins = 321
	GameState.current_zone = &"fun_park"
	var bait := Database.item(&"bait")
	GameState.inventory.add(bait, 7)
	_check(SaveManager.save_game(), "save written")
	# fake 1 hour offline: rewrite the timestamp
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.path))
	data.unix = float(data.unix) - 3600.0
	FileAccess.open(SaveManager.path, FileAccess.WRITE).store_string(JSON.stringify(data))
	farm.free()
	GameState.coins = 0
	GameState.inventory.remove(bait, 7)
	Progression.level = 1
	var clock_before := GameState.clock
	_check(SaveManager.load_game(), "save loaded")
	_check(GameState.coins == 321 and GameState.current_zone == &"fun_park" and Progression.level == 3, "wallet, zone, level restored")
	_check(GameState.inventory.count(bait) >= 7, "inventory restored")
	_check(GameState.clock >= clock_before + 3599.0, "offline hour added to the clock")
	var farm2: Node = load("res://scenes/zones/my_farm.tscn").instantiate()
	add_child(farm2)
	await get_tree().process_frame
	var plot2 := (farm2.get_node(^"FarmGrid") as FarmGrid).get_plot(Vector2i(1, 1))
	_check(plot2.crop == Database.crop(&"pumpkin") and plot2.stage == 1 and not plot2.is_watered, "pumpkin restored, grew one stage offline, now dry")
	_check(not SaveManager._pending.has("farm_grid"), "pending farm data consumed")
	farm2.free()

	# corrupt save is set aside, never crashes
	FileAccess.open(SaveManager.path, FileAccess.WRITE).store_string("{not json")
	_check(not SaveManager.load_game() and FileAccess.file_exists(SaveManager.path + ".bad"), "corrupt save kept as .bad")
	DirAccess.remove_absolute(SaveManager.path + ".bad")


func test_farm_plus() -> void:
	var inv := GameState.inventory
	var farm: Node = load("res://scenes/zones/my_farm.tscn").instantiate()
	add_child(farm)
	await get_tree().process_frame
	var grid: FarmGrid = farm.get_node(^"FarmGrid")

	# crop care: weeds/pests pause growth, fertilizer halves stage time
	var plot := grid.get_plot(Vector2i(0, 0))
	plot.perform(&"till")
	plot.perform(&"plant", Database.crop(&"carrot"))
	plot.perform(&"fertilize")
	_check(plot.fertilized and not plot.can(&"fertilize"), "fertilized once")
	plot.problem_chance = 1.0
	plot.perform(&"water")
	GameState.clock += 2.0 # carrot stage = 4 s, fertilized = 2 s
	plot._process(0.0)
	_check(plot.stage == 1 and plot.problem != FarmPlot.Problem.NONE, "fertilized stage done in half time, problem appeared")
	plot.perform(&"water")
	GameState.clock += 50.0
	plot._process(0.0)
	_check(plot.stage == 1, "weeds/pests block growth even when watered")
	var fix: StringName = &"weed" if plot.problem == FarmPlot.Problem.WEEDS else &"spray"
	_check(plot.can(fix), "plot offers the right fix")
	plot.perform(fix)
	_check(plot.problem == FarmPlot.Problem.NONE, "problem removed")

	# land expansion
	var cols := grid.size.x
	_check(grid.expand_cost() == 150 and grid.expand_level() == 2, "first expansion: 150 xu, level 2")
	grid.expand()
	_check(grid.size.x == cols + 1 and grid.get_plot(Vector2i(cols, 0)) != null, "expansion adds a column of plots")

	# recipes + machine
	var juicer: Machine = farm.get_node(^"Juicer")
	var tomato := Database.item(&"tomato")
	var juice: RecipeData = Database.recipes[&"tomato_juice"]
	_check(Database.recipes_for(&"juicer").size() == 2, "juicer has 2 recipes")
	inv.add(tomato, 3)
	var before := inv.count(tomato)
	_check(juicer.start(juice) and inv.count(tomato) == before - 3, "machine takes recipe inputs")
	_check(not juicer.start(juice), "one job at a time")
	_check(not juicer.is_done(), "job not done yet")
	GameState.clock += juice.duration
	var juice_before := inv.count(juice.output)
	juicer.interact(null)
	_check(inv.count(juice.output) == juice_before + 1 and juicer.job == null, "collect finished product")

	# animals
	var pen: AnimalPen = farm.get_node(^"AnimalPen")
	inv.add(Database.item(&"chick"), 2)
	pen.interact(null)
	_check(pen.count() == 2 and inv.count(Database.item(&"chick")) == 0, "young animals released into the pen")
	var hen := pen._animals.get_child(0) as Animal
	inv.add(Database.item(&"animal_feed"), 1)
	hen.interact(null)
	_check(hen.fed_at >= 0.0, "animal fed with 1 feed")
	GameState.clock += hen.data.produce_time
	hen._process(0.0)
	var eggs := inv.count(Database.item(&"egg"))
	hen.interact(null)
	_check(inv.count(Database.item(&"egg")) == eggs + 1 and not hen.has_product and hen.fed_at < 0.0, "egg collected, hen hungry again")

	# home pond
	var pond: FishPond = farm.get_node(^"HomePond")
	inv.add(Database.item(&"fingerling"), 1)
	pond.interact(null)
	_check(pond.stocked_at >= 0.0 and not pond.is_grown(), "pond stocked")
	GameState.clock += pond.grow_time
	var fish_before: int = inv.items(ItemData.Category.FISH).reduce(func(n: int, it: ItemData) -> int: return n + inv.count(it), 0)
	pond.interact(null)
	var fish_after: int = inv.items(ItemData.Category.FISH).reduce(func(n: int, it: ItemData) -> int: return n + inv.count(it), 0)
	_check(fish_after == fish_before + pond.catch_count and pond.stocked_at < 0.0, "netted fish from the pond")

	# delivery orders
	var board: OrderBoard = farm.get_node(^"OrderBoard")
	_check(board.orders.size() == 3, "3 orders on the board")
	var order: Dictionary = board.orders[0]
	for id: String in order.items:
		inv.add(Database.item(StringName(id)), int(order.items[id]))
	var coins := GameState.coins
	_check(board.can_fill(order) and board.deliver(0), "order delivered")
	_check(GameState.coins == coins + int(order.coins), "order paid")
	_check(float(board.orders[0].ready_at) > GameState.clock, "slot refills after a cooldown")

	# everything survives a save/load
	_check(SaveManager.save_game(), "farm extras saved")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.path))
	_check(data.world.has("animal_pen") and data.world.has("machine_juicer") and data.world.has("order_board") and data.world.has("home_pond"), "all farm systems in the save")
	_check(int(data.world.farm_grid.columns) == cols + 1, "expanded columns saved")
	farm.free()
	SaveManager.load_game()
	var farm2: Node = load("res://scenes/zones/my_farm.tscn").instantiate()
	add_child(farm2)
	await get_tree().process_frame
	_check((farm2.get_node(^"FarmGrid") as FarmGrid).size.x == cols + 1, "expansion restored")
	_check((farm2.get_node(^"AnimalPen") as AnimalPen).count() == 2, "animals restored")
	farm2.free()

	# v1 save (plots only) still loads
	FileAccess.open(SaveManager.path, FileAccess.WRITE).store_string(JSON.stringify({"version": 1, "unix": 0, "farm": [{"cell": [0, 0], "state": 1}]}))
	_check(SaveManager.load_game() and SaveManager._pending.farm_grid.plots.size() == 1, "v1 save migrated")


func test_house() -> void:
	SaveManager._pending.erase("house")
	var inv := GameState.inventory
	var root: Node = load("res://scenes/zones/my_house.tscn").instantiate()
	add_child(root)
	await get_tree().process_frame
	var house := root as House
	_check(Database.furniture.size() >= 20, "20+ furniture kinds")
	_check(house.beauty() > 0 and house.furniture_at(Vector2i(0, 0)) != null, "new house has starter furniture")
	var start_beauty := house.beauty()

	var sofa: FurnitureData = Database.furniture[&"sofa"]
	_check(sofa.size_for(0) == Vector2i(2, 1) and sofa.size_for(1) == Vector2i(1, 2), "rotation swaps footprint")
	_check(house.place(sofa, Vector2i(5, 4), 0) == null, "cannot place furniture you do not own")
	inv.add(sofa.item, 1)
	_check(not house.can_place(sofa, Vector2i(7, 4), 0), "footprint must stay inside the room")
	var placed := house.place(sofa, Vector2i(5, 4), 0)
	_check(placed != null and inv.count(sofa.item) == 0, "placed sofa uses the bag item")
	_check(house.furniture_at(Vector2i(6, 4)) == placed, "sofa covers both cells")
	inv.add(sofa.item, 1)
	_check(not house.can_place(sofa, Vector2i(6, 4), 1), "no overlap on the solid layer")
	var rug: FurnitureData = Database.furniture[&"rug_rect"]
	inv.add(rug.item, 1)
	_check(house.place(rug, Vector2i(5, 4), 0) != null, "rugs go under furniture (floor layer)")
	_check(house.beauty() == start_beauty + sofa.beauty + rug.beauty, "beauty adds up")

	# decorate-mode click picks up / places
	house.select(null)
	house.click_cell(Vector2i(5, 4))
	_check(house.furniture_at(Vector2i(5, 4)) != placed and inv.count(sofa.item) == 2, "click picks furniture back up")
	house.select(sofa)
	house.click_cell(Vector2i(0, 4))
	_check(house.furniture_at(Vector2i(1, 4)) != null, "click places the selection")

	# sitting
	var p: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	var seat := house.furniture_at(Vector2i(0, 4))
	p.sit_on(seat)
	_check(p.is_sitting() and p.global_position.distance_to(seat.seat_point()) < 0.01, "player sits on the sofa")
	p.try_interact()
	_check(not p.is_sitting(), "E stands up")
	p.free()

	# styles + save round trip
	house.next_floor()
	house.next_wall()
	var saved := house.to_save()
	_check(int(saved.floor) == 1 and int(saved.wall) == 1 and saved.items.size() == house._items.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size(), "house state serialized")
	root.free()
	SaveManager._pending["house"] = JSON.parse_string(JSON.stringify(saved))
	var root2: Node = load("res://scenes/zones/my_house.tscn").instantiate()
	add_child(root2)
	await get_tree().process_frame
	_check((root2 as House).to_save().items.size() == saved.items.size() and (root2 as House).floor_style == 1, "house layout restored")
	root2.free()


func test_fashion() -> void:
	var inv := GameState.inventory
	SaveManager._pending.erase("appearance")
	var p: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	_check(Database.outfits.size() >= 12 and Database.pets.size() == 6, "outfits and pets loaded")

	# accessories attach to bones at sensible anchors
	var model: Node3D = p.visual.get_node(^"Model")
	var skel := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var anchors := Avatar._anchors(skel)
	_check(anchors[OutfitData.Slot.HAT][1].y > anchors[OutfitData.Slot.GLASSES][1].y, "hat sits above the glasses")
	_check(anchors[OutfitData.Slot.GLASSES][1].y > anchors[OutfitData.Slot.NECK][1].y, "glasses above the neck")
	_check(anchors[OutfitData.Slot.BACK][1].z < anchors[OutfitData.Slot.GLASSES][1].z, "back item behind the face")
	var hat: OutfitData = Database.outfits[&"hat_straw"]
	var wings: OutfitData = Database.outfits[&"angel_wings"]
	p.equip_outfit(hat)
	p.equip_outfit(wings)
	_check(skel.has_node(NodePath("Acc%d" % OutfitData.Slot.HAT)) and skel.has_node(NodePath("Acc%d" % OutfitData.Slot.BACK)), "accessories attached to the skeleton")
	p.unequip(OutfitData.Slot.BACK)
	await get_tree().process_frame
	_check(not skel.has_node(NodePath("Acc%d" % OutfitData.Slot.BACK)) and p.equipped.size() == 1, "unequip removes the accessory")

	# base character swap keeps the outfit
	p.owned_bases.append("character-male-c")
	p.set_base("character-male-c")
	await get_tree().process_frame
	var skel2 := p.visual.get_node(^"Model").find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_check(skel2 != skel and skel2.has_node(NodePath("Acc%d" % OutfitData.Slot.HAT)) and p.anim != null, "new base keeps hat and animations")

	# premium currency
	GameState.gems = 10
	_check(not GameState.spend_gems(wings.gem_price) and GameState.gems == 10, "cannot buy wings without enough Lượng")
	GameState.gems = 100
	_check(GameState.spend_gems(wings.gem_price) and GameState.gems == 100 - wings.gem_price, "wings bought with Lượng")

	# pets: follow + race guest
	var dog: PetData = Database.pets[&"pet_dog"]
	inv.add(dog.item)
	p.set_active_pet(dog)
	_check(p.pet_companion().visible and p.pet_level() == 1, "active pet follows, level 1")
	p.add_affection(45)
	_check(p.pet_level() == 3 and dog.race_speed(45) > dog.base_speed, "affection raises level and race speed")
	var race: PetRace = load("res://scenes/minigames/pet_race.tscn").instantiate()
	add_child(race)
	race.set_guest(dog, 45)
	_check(race.racers[4].name.begins_with(dog.display_name) and race.racers[4].payout == 3, "your pet runs in the last lane")
	race.set_guest(null)
	_check(race.racers[4].name == "Heo Ủn", "house racer restored without a pet")
	race.queue_free()

	# appearance save round trip
	var saved := p.to_save()
	p.free()
	var p2: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child(p2)
	await get_tree().process_frame
	p2.load_save(JSON.parse_string(JSON.stringify(saved)))
	_check(p2.base_id == "character-male-c" and p2.equipped.get(OutfitData.Slot.HAT) == hat and p2.active_pet == dog, "appearance and pet restored")
	_check(p2.pet_level() == 3, "pet affection restored")
	p2.free()

	# admin login uses the config file
	var admin := AdminPanel.new()
	var cfg := ConfigFile.new()
	_check(cfg.load(AdminPanel.CONFIG) == OK, "admin config present")
	admin._cfg = cfg
	_check(admin.check(str(cfg.get_value("admin", "username")), str(cfg.get_value("admin", "password"))), "admin credentials accepted")
	_check(not admin.check("admin", "wrong") and not admin.check("", ""), "wrong admin password rejected")
	admin.free()


func test_camera() -> void:
	# fast right-drag across 180 degrees must not spin the camera the long way round
	var p: Player = load("res://scenes/player/player.tscn").instantiate()
	add_child(p)
	await get_tree().process_frame
	var cam := p.cam
	cam.yaw = 170.0
	cam.snap()
	var drag := InputEventMouseMotion.new()
	drag.relative = Vector2(-200, 0) # +60 degrees in one event
	cam.yaw -= drag.relative.x * cam.rotate_sensitivity
	var prev: float = cam.global_rotation_degrees.y
	var worst := 0.0
	for i in 60:
		cam._process(1.0 / 60.0)
		var now: float = cam.global_rotation_degrees.y
		worst = maxf(worst, absf(wrapf(now - prev, -180.0, 180.0)))
		prev = now
	_check(worst < 15.0, "camera turns smoothly across 180 degrees (max step %.1f)" % worst)
	_check(absf(wrapf(cam.global_rotation_degrees.y - 230.0, -180.0, 180.0)) < 2.0, "camera ends at the dragged yaw")
	p.free()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: " + msg)
