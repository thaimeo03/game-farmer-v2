extends Node
## Run: godot --headless --path . tests/run_tests.tscn   (exit code 1 on failure)
## A scene (not a -s script) so autoloads like GameState are available.

var _fails := 0


func _ready() -> void:
	Quests.enabled = false # quest rewards would disturb the coin checks; test_social turns it back on
	await get_tree().process_frame
	await test_farm()
	test_economy()
	test_minigames()
	await test_world()
	await test_farm_plus()
	await test_house()
	await test_fashion()
	await test_camera()
	await test_fun()
	await test_social()
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
	_check(gs.time_text().begins_with("Ngày 1  06:00"), "clock start")
	gs.clock = 18.0 * 60.0 / gs.MINUTES_PER_SECOND
	_check(gs.time_text().begins_with("Ngày 2  00:00"), "clock rolls day")



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

	var counts := {}
	for i in 4000:
		var id: StringName = FishingSpot.pick(FishingSpot.TABLES[&"fresh"])[0]
		counts[id] = counts.get(id, 0) + 1
	_check(counts.size() == 5, "every freshwater catch can happen")
	_check(counts[&"fish_gold"] == counts.values().min(), "gold fish is the rarest catch")
	_check(Database.item(&"fish_gold").sell_price > Database.item(&"fish_perch").sell_price, "rare fish sells for more")
	for table: StringName in FishingSpot.TABLES:
		for e: Array in FishingSpot.TABLES[table]:
			_check(Database.item(e[0]) != null, "catch %s exists" % e[0])


func test_world() -> void:
	# content database
	_check(Database.item(&"fish_gold") != null and Database.crop(&"tomato") != null, "database finds items and crops by id")
	_check(Database.zones.size() == 8 and Database.zones[0].id == &"my_farm", "8 zones, ordered")
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


func test_fun() -> void:
	# daily limits
	GameState.daily.clear()
	_check(GameState.daily_use("x", 2) and GameState.daily_use("x", 2) and not GameState.daily_use("x", 2), "daily limit enforced")
	GameState.clock += 24 * 60 / GameState.MINUTES_PER_SECOND
	_check(GameState.daily_use("x", 2), "limit resets the next day")

	# lucky wheel: weighted prizes, pays with coins or a ticket, 5 spins a day
	var counts := [0, 0, 0, 0, 0, 0, 0, 0]
	for i in 4000:
		counts[LuckyWheel.pick_prize()] += 1
	_check(counts.min() > 0 and counts[6] == counts.min(), "every prize possible, outfit is the rarest")
	var park: Node = load("res://scenes/zones/fun_park.tscn").instantiate()
	add_child(park)
	await get_tree().process_frame
	var wheel: LuckyWheel = park.get_node(^"LuckyWheel")
	GameState.daily.clear()
	GameState.coins = 1000
	var coins_before := GameState.coins
	_check((await wheel.spin(false, false)) >= 0 and GameState.coins != coins_before, "spin with coins")
	GameState.inventory.add(Database.item(&"spin_ticket"), 1)
	var tickets := GameState.inventory.count(Database.item(&"spin_ticket"))
	_check((await wheel.spin(true, false)) >= 0, "spin with a ticket")
	_check(GameState.inventory.count(Database.item(&"spin_ticket")) <= tickets, "ticket used (a ticket prize may refund it)")
	for i in 3:
		await wheel.spin(false, false)
	_check((await wheel.spin(false, false)) == -1, "no 6th spin today")

	# ferris wheel cabins stay on the rim
	var ferris: FerrisWheel = park.get_node(^"FerrisWheel")
	for i in ferris.cabins:
		_check(absf(ferris.cabin_position(i).distance_to(ferris.get_node(^"Ring").position) - ferris.radius) < 0.01, "cabin %d on the rim" % i)

	# ring toss prizes grow with hits
	var c0 := GameState.coins
	RingToss.award(3)
	_check(GameState.coins == c0 + 100, "3 hits pay 100 xu")
	park.free()

	# caro: rules, win detection, AI never plays an occupied cell, blocks a four
	var game := CaroGame.new()
	for x in 4:
		game.play(x, 7, 1)
	_check(game.ai_move(2) == Vector2i(4, 7), "hard AI blocks an open four")
	game.play(4, 7, 1)
	_check(game.winner == 1, "five in a row wins")
	_check(not game.play(0, 0, 2), "no moves after the game ends")
	var g2 := CaroGame.new()
	var legal := true
	for i in 60:
		var who := 1 + i % 2
		var m := g2.ai_move(i % 3)
		if g2.at(m.x, m.y) != 0:
			legal = false
		if not g2.play(m.x, m.y, who):
			break
	_check(legal, "AI only picks empty cells")

	# fish journal records sizes and records
	GameState.fish_journal.clear()
	var tuna := Database.item(&"fish_tuna")
	var r1 := GameState.record_fish(tuna)
	_check(r1[0] >= tuna.size_range.x and r1[0] <= tuna.size_range.y and not r1[1], "first catch has a size, not a 'record'")
	GameState.record_fish(tuna)
	_check(int(GameState.fish_journal["fish_tuna"].count) == 2, "journal counts catches")

	# island and beach scenes load with their pieces
	var isle: Node = load("res://scenes/zones/little_isle.tscn").instantiate()
	add_child(isle)
	await get_tree().process_frame
	var terrain: Terrain = isle.get_node(^"Terrain")
	_check(terrain.height_at(0, 0) >= 0.0 and terrain.height_at(0, -40) < terrain.water_level, "island land in the middle, sea around")
	var chest: TreasureChest = isle.get_node(^"TreasureChest")
	GameState.daily.clear()
	var c1 := GameState.coins
	chest.interact(null)
	chest.interact(null)
	_check(GameState.coins - c1 >= 100 and GameState.coins - c1 <= 300, "treasure opens once a day")
	isle.free()




## Sets the clock to day `d` (0-based), minute `m` of that day.
func _at(d: int, m: int) -> void:
	GameState.clock = (d * 1440 + m - GameState.DAY_START_MINUTE) / GameState.MINUTES_PER_SECOND
	GameState.rain_until = 0.0


func test_social() -> void:
	# --- weather & day/night
	_check(GameState.rain_window(0).x == -1, "first day is always dry")
	_check(GameState.rain_window(7) == GameState.rain_window(7), "rain is deterministic")
	var wet := 0
	var daytime := true
	for d in range(1, 301):
		var w := GameState.rain_window(d)
		if w.x >= 0:
			wet += 1
			daytime = daytime and w.y > w.x and w.x >= 8 * 60 and w.y <= 19 * 60
	_check(wet > 60 and wet < 150, "about a third of days rain (%d/300)" % wet)
	_check(daytime, "rain only in daytime hours")
	var rainy := 1
	while GameState.rain_window(rainy).x < 0:
		rainy += 1
	var win := GameState.rain_window(rainy)
	_at(rainy, win.x + 10)
	_check(GameState.is_raining(), "raining inside the window")
	_at(rainy, win.y + 10)
	_check(not GameState.is_raining() and GameState.has_rainbow(), "rainbow right after the rain")
	_check(DayNight.daylight(12 * 60) == 1.0 and DayNight.daylight(0) == 0.0, "noon bright, midnight dark")

	var farm: Node = load("res://scenes/zones/my_farm.tscn").instantiate()
	add_child(farm)
	await get_tree().process_frame
	var grid: FarmGrid = farm.get_node(^"FarmGrid")
	var plot := grid.get_plot(Vector2i(0, 0))
	plot.problem_chance = 0.0
	plot.perform(&"till")
	plot.perform(&"plant", Database.crop(&"carrot"))
	_at(0, 9 * 60) # day 1 never rains
	for i in 40:
		await get_tree().process_frame
	_check(plot.can(&"water"), "no rain: the plot stays dry")
	GameState.rain_until = GameState.clock + 600.0
	for i in 40:
		await get_tree().process_frame
	_check(plot.is_watered, "rain waters the crops")
	GameState.rain_until = 0.0

	# --- neighbors: data, schedules point at real places
	_check(Database.npcs.size() >= 6, "6+ neighbors")
	var scenes := {}
	for npc: NpcData in Database.npcs.values():
		_check(npc.display_name != "" and npc.lines.size() > 0 and npc.quest != null and npc.outfits.size() > 0, "%s has looks, lines and a quest" % npc.id)
		for entry in npc.schedule:
			var parts := entry.split(" ")
			if parts[1] == "home":
				continue
			var zone := Database.zone(StringName(parts[1]))
			_check(zone != null, "%s: zone %s exists" % [npc.id, parts[1]])
			if zone and not scenes.has(zone.id):
				scenes[zone.id] = load(zone.scene_path).instantiate()
			_check(zone != null and scenes[zone.id].find_child(parts[2], true, false) != null, "%s: anchor %s in %s" % [npc.id, parts[2], parts[1]])
	var tam: NpcData = Database.npcs[&"bac_tam"]
	_check(tam.where(7 * 60) == PackedStringArray(["market_town", "SeedShop"]), "Bác Tâm at the seed shop at 7:00")
	_check(tam.where(2 * 60)[0] == "home", "Bác Tâm home at night")
	_at(3, Social.VISIT_MINUTE + 5)
	_check(Social.where(Social.visitor(), GameState.minute_of_day())[0] == "my_farm", "the day's visitor is at the farm")

	# director: spawn at the schedule spot, leave when the schedule moves on, walk there
	var town: Node3D = scenes[&"market_town"]
	add_child(town)
	var director := NeighborDirector.new()
	add_child(director)
	_at(3, 7 * 60)
	director.enter(town, &"market_town")
	var tam_n: Neighbor = director._people.get(&"bac_tam")
	_check(tam_n != null, "Bác Tâm spawned in town at 7:00")
	await get_tree().physics_frame
	var shop: Node3D = town.get_node(^"SeedShop")
	_check(tam_n != null and tam_n.global_position.distance_to(shop.global_position) < 6.0, "standing by the seed shop")
	_at(3, 11 * 60 + 5)
	director.update(false)
	_check(tam_n != null and tam_n.leaving, "leaves when the schedule says bus terminal")
	var d0 := tam_n.global_position.distance_to(director.entry())
	for i in 60:
		await get_tree().physics_frame
	_check(is_instance_valid(tam_n) and tam_n.global_position.distance_to(director.entry()) < d0 - 0.8, "walks towards the bus stop")
	# event decor + stall during the Mid-Autumn days
	_at(12, 9 * 60) # day 13 of the month
	_check(Quests.active_event() != null and Quests.active_event().id == &"mid_autumn", "Mid-Autumn active on day 13")
	director.update(false)
	var decor := town.get_node_or_null(^"EventSpot/EventDecor")
	_check(decor != null and decor.find_children("*", "ShopNpc", true, false).size() == 1, "event stall put up in town")
	_at(20, 9 * 60)
	director.update(false)
	await get_tree().process_frame
	_check(town.get_node_or_null(^"EventSpot/EventDecor") == null, "decor removed after the event")
	director.free()
	for z: Node in scenes.values():
		z.free()

	# --- friendship, gifts, mail, farm visit
	Social.points.clear()
	GameState.daily.clear()
	Social.talk(tam)
	Social.talk(tam)
	_check(int(Social.points["bac_tam"]) == 2, "first chat of the day counts once")
	var pumpkin := Database.item(&"pumpkin")
	GameState.inventory.add(pumpkin, 2)
	Social.gift(tam, pumpkin)
	_check(int(Social.points["bac_tam"]) == 10, "a liked gift gives 8")
	_check(Social.gift(tam, pumpkin).begins_with("Hôm nay") and GameState.inventory.count(pumpkin) == 1, "one gift a day, item kept")
	Social.points["bac_tam"] = 59
	GameState.daily.clear()
	Social.talk(tam)
	_check(Social.hearts(&"bac_tam") == 3, "3 hearts at 60 points")
	Social.mail.clear()
	_at(5, Social.VISIT_MINUTE + 1)
	var plot2 := grid.get_plot(Vector2i(1, 0))
	plot2.problem_chance = 0.0
	plot2.perform(&"till")
	plot2.perform(&"plant", Database.crop(&"carrot"))
	_check(Social.run_visit(grid) and not Social.run_visit(grid), "one farm visit a day")
	_check(plot2.is_watered and Social.mail.size() == 1, "the visitor watered and left a letter")
	var gift_item := Database.item(StringName(Social.mail[0].item))
	var had := GameState.inventory.count(gift_item)
	Social.claim(0)
	_check(GameState.inventory.count(gift_item) == had + 2 and Social.mail.is_empty(), "claiming a letter gives its gift")
	farm.free()

	# --- quests: the whole tutorial, dailies, NPC quest, event quest
	Quests.enabled = true
	Quests.active.clear()
	Quests.done.clear()
	Quests._daily_day = -1
	_at(0, 7 * 60)
	Quests.start(Quests.TUTORIAL_START, true)
	for q: QuestData in Database.quests.values():
		for step: Dictionary in q.steps:
			if step.has("at") and step.has("zone"):
				var z: Node = load(Database.zone(StringName(step.zone)).scene_path).instantiate()
				_check(z.find_child(step.at, true, false) != null, "%s guide target %s exists" % [q.id, step.at])
				z.free()
	var coins := GameState.coins
	for a: StringName in [&"till", &"plant", &"water"]:
		Quests.notify(a)
	_check(Quests.is_done(&"tut_1") and Quests.is_active(&"tut_2") and GameState.coins == coins + 30, "tutorial 1 done, pays, chains to 2")
	for a: Array in [[&"mail"], [&"harvest"], [&"visit", &"fun_park"], [&"visit", &"market_town"], [&"sell"], [&"buy"], [&"talk"], [&"emote"], [&"gift"]]:
		Quests.notify(a[0], a[1] if a.size() > 1 else &"")
	_check(Quests.is_done(&"tut_4") and not Quests.is_active(&"tut_3"), "a new player is guided through the whole tutorial")
	var dailies := Quests.active.keys().filter(func(id: String) -> bool: return id.begins_with("daily_"))
	var done_dailies := Quests.done.keys().filter(func(id: String) -> bool: return id.begins_with("daily_"))
	_check(dailies.size() + done_dailies.size() == Quests.DAILY_COUNT and dailies.size() > 0, "3 daily quests (the tutorial may already finish one)")
	var first_daily := Quests.quest(StringName(dailies[0]))
	coins = GameState.coins
	Quests.notify(StringName(first_daily.steps[0].do), &"", int(first_daily.steps[0].count))
	_check(Quests.is_done(first_daily.id) and GameState.coins >= coins + first_daily.reward_coins, "daily quest completes and pays")
	_at(1, 7 * 60)
	Quests.notify(&"nothing")
	_check(not Quests.is_active(first_daily.id) and not Quests.is_done(first_daily.id), "yesterday's dailies are gone")
	_check(Quests.active.keys().filter(func(id: String) -> bool: return id.begins_with("daily_1_")).size() == 3, "new dailies today")
	Quests.start(tam.quest.id)
	Quests.notify(&"gift", &"carrot")
	_check(Quests.is_active(tam.quest.id), "NPC quest wants a pumpkin, not a carrot")
	Quests.notify(&"gift", &"pumpkin")
	_check(Quests.is_done(tam.quest.id), "NPC quest done with the right gift")
	Social.mail.clear()
	_at(42, 9 * 60) # day 13 of the second month
	Quests.notify(&"nothing")
	_check(Quests.is_active(&"ev_mid_autumn") and Social.mail.size() == 1, "event quest and letter when the festival starts")
	Quests.notify(&"buy", &"mooncake", 3)
	Quests.notify(&"gift", &"mooncake", 3)
	_check(Quests.is_done(&"ev_mid_autumn"), "event quest completes")
	_at(50, 9 * 60)
	Quests.notify(&"nothing")
	_check(not Quests.is_active(&"ev_mid_autumn"), "no event quest outside the festival")
	var saved := Quests.to_save()
	Quests.active.clear()
	Quests.load_save(JSON.parse_string(JSON.stringify(saved)))
	_check(Quests.is_done(&"tut_4") and Quests.active.size() == 3, "quests survive save/load")
	Quests.enabled = false

func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		printerr("FAIL: " + msg)
