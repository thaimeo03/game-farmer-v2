class_name Salon
extends ShopNpc
## Beauty salon: change the base character (13 looks). Try on the preview, buy once, switch freely.


func interact(player: Player) -> void:
	hud().open_preview_shop(title, _entries.bind(player), player)


func _entries(player: Player) -> Array:
	var hud := hud()
	var rows := []
	for base in Avatar.BASES:
		var owned := base in player.owned_bases
		var current := base == player.base_id
		var buttons := [["Thử", hud.set_preview.bind(base, player.equipped), true]]
		if current:
			buttons.append(["Đang dùng", func() -> void: pass, false])
		elif owned:
			buttons.append(["Dùng", player.set_base.bind(base), true])
		else:
			buttons.append(["Mua", _buy.bind(player, base), GameState.coins >= Avatar.BASE_PRICE])
		rows.append({"text": "%s\n%s" % [Avatar.base_name(base), "Đã có" if owned else "%d xu" % Avatar.BASE_PRICE], "buttons": buttons})
	return rows


func _buy(player: Player, base: String) -> void:
	if GameState.spend(Avatar.BASE_PRICE):
		player.owned_bases.append(base)
		player.set_base(base)
		GameState.toast("Diện mạo mới!")
