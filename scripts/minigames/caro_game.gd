class_name CaroGame
extends RefCounted
## Gomoku / caro rules on a SIZE x SIZE board: 5 in a row wins. Player = 1 (X), AI = 2 (O).
## AI levels: 0 easy (random among good moves), 1 normal (best heuristic), 2 hard (wins or
## blocks immediately, weighs defence higher).

const SIZE := 15
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]

var board := PackedInt32Array()
var winner := 0 ## 0 none, 1 player, 2 AI, 3 draw
var moves := 0


func _init() -> void:
	board.resize(SIZE * SIZE)


func at(x: int, y: int) -> int:
	return board[y * SIZE + x] if inside(x, y) else -1


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < SIZE and y < SIZE


func play(x: int, y: int, who: int) -> bool:
	if winner != 0 or at(x, y) != 0:
		return false
	board[y * SIZE + x] = who
	moves += 1
	if _run_length(x, y, who) >= 5:
		winner = who
	elif moves == SIZE * SIZE:
		winner = 3
	return true


func ai_move(level: int) -> Vector2i:
	var cells := _candidates()
	if level >= 1:
		for who in [2, 1]: # hard/normal: take a win, else block the player's win
			for c in cells:
				board[c.y * SIZE + c.x] = who
				var five := _run_length(c.x, c.y, who) >= 5
				board[c.y * SIZE + c.x] = 0
				if five:
					return c
	var scored := []
	for c in cells:
		var attack := _score(c.x, c.y, 2)
		var defend := _score(c.x, c.y, 1)
		var s: float = attack + defend * (1.2 if level == 2 else 0.9) + randf() * (5.0 if level < 2 else 0.5)
		scored.append([s, c])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	if level == 0:
		return scored[randi() % mini(6, scored.size())][1]
	return scored[0][1]


## Empty cells within 2 of any stone (or the center on an empty board).
func _candidates() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if moves == 0:
		out.append(Vector2i(SIZE / 2, SIZE / 2))
		return out
	for y in SIZE:
		for x in SIZE:
			if at(x, y) != 0:
				continue
			var near := false
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if at(x + dx, y + dy) > 0:
						near = true
			if near:
				out.append(Vector2i(x, y))
	return out


## Longest line through (x, y) for `who` (the stone must already be there).
func _run_length(x: int, y: int, who: int) -> int:
	var best := 0
	for d in DIRS:
		var n := 1
		for sgn: int in [1, -1]:
			var p := Vector2i(x, y) + d * sgn
			while at(p.x, p.y) == who:
				n += 1
				p += d * sgn
		best = maxi(best, n)
	return best


## Heuristic value of putting `who` at an empty (x, y): longer and more open lines score more.
func _score(x: int, y: int, who: int) -> float:
	var total := 0.0
	for d in DIRS:
		var n := 0
		var open := 0
		for sgn: int in [1, -1]:
			var p := Vector2i(x, y) + d * sgn
			while at(p.x, p.y) == who:
				n += 1
				p += d * sgn
			if at(p.x, p.y) == 0:
				open += 1
		if n >= 4:
			total += 10000.0
		elif n == 3:
			total += 1000.0 if open == 2 else 150.0
		elif n == 2:
			total += 100.0 if open == 2 else 15.0
		elif n == 1:
			total += 10.0 if open == 2 else 2.0
	return total
