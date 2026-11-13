class_name ScoreManager
extends RefCounted

var score: int = 0
var combo: int = 0
var max_combo: int = 0
var perfects: int = 0
var goods: int = 0
var misses: int = 0
var multiplier: int = 1

# Rastreio de Eventos Musicais para Accuracy
var total_events: int = 0
var events_perfect: int = 0
var events_good: int = 0
var events_miss: int = 0

func set_total_events(total: int) -> void:
	total_events = total

func add_event_result(result: String) -> void:
	if result == "perfect": events_perfect += 1
	elif result == "good": events_good += 1
	else: events_miss += 1

func add_hit(is_perfect: bool) -> void:
	combo += 1
	if combo > max_combo:
		max_combo = combo

	multiplier = mini(4, 1 + (combo / 10))

	if is_perfect:
		score += 100 * multiplier
		perfects += 1
	else:
		score += 70 * multiplier
		goods += 1

func add_chord_hit(hits: Array) -> void:
	combo += 1
	if combo > max_combo:
		max_combo = combo
	multiplier = mini(4, 1 + (combo / 10))

	for is_perfect in hits:
		if is_perfect:
			score += 100 * multiplier
			perfects += 1
		else:
			score += 70 * multiplier
			goods += 1

func complete_hold() -> void:
	score += 100 * multiplier

func add_miss() -> void:
	combo = 0
	multiplier = 1
	misses += 1

func get_accuracy() -> float:
	var total_resolved = events_perfect + events_good + events_miss
	if total_resolved == 0: return 0.0
	var weighted = (events_perfect * 1.0) + (events_good * 0.7)
	return clampf((weighted / float(total_resolved)) * 100.0, 0.0, 100.0)

func get_rank() -> String:
	var acc = get_accuracy()
	if acc >= 95.0: return "S"
	if acc >= 90.0: return "A"
	if acc >= 80.0: return "B"
	if acc >= 70.0: return "C"
	return "D"
