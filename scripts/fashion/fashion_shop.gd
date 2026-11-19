class_name FashionShop
extends ShopNpc
## Clothes shop with a fitting room: every accessory can be tried on the 3D preview
## before buying (xu, or Lượng for premium pieces), then worn straight away.


func interact(player: Player) -> void:
	hud().open_preview_shop(title, _entries.bind(player), player)


func _entries(player: Player) -> Array:
	var hud := hud()
	var list: Array = Database.outfits.values()
	list.sort_custom(func(a: OutfitData, b: OutfitData) -> bool: return a.slot < b.slot if a.slot != b.slot else a.item.display_name < b.item.display_name)
	var rows := []
	for o: OutfitData in list:
		var owned := GameState.inventory.count(o.item) > 0
		if o.event_only and not owned:
			continue
		var worn: bool = player.equipped.get(o.slot) == o
		var locked := Progression.level < o.unlock_level
		var price := "%d Lượng" % o.gem_price if o.gem_price > 0 else "%d xu" % o.item.buy_price
		var state := "Đang mặc" if worn else ("Đã có" if owned else ("Cần cấp %d" % o.unlock_level if locked else price))
		var tried := player.equipped.duplicate()
		tried[o.slot] = o
		var buttons := [["Thử", hud.set_preview.bind(player.base_id, tried), true]]
		if not owned:
			buttons.append(["Mua", _buy.bind(o), not locked])
		elif worn:
			buttons.append(["Bỏ", player.unequip.bind(o.slot), true])
		else:
			buttons.append(["Mặc", player.equip_outfit.bind(o), true])
		rows.append({"text": "%s  [%s]\n%s" % [o.item.display_name, OutfitData.SLOT_NAMES[o.slot], state], "buttons": buttons})
	return rows


func _buy(o: OutfitData) -> void:
	var paid := GameState.spend_gems(o.gem_price) if o.gem_price > 0 else GameState.spend(o.item.buy_price)
	if paid:
		GameState.inventory.add(o.item)
		GameState.toast("Đã mua %s" % o.item.display_name)
