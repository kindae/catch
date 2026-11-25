## État global : configuration du combat, modes de jeu, progression et déblocages.
extends Node

enum Mode { QUICK, TRAINING, TOURNAMENT, SURVIVAL, CAREER }

const MODE_NAMES := {
	Mode.QUICK: "Combat rapide", Mode.TRAINING: "Entraînement", Mode.TOURNAMENT: "Tournoi",
	Mode.SURVIVAL: "Survie", Mode.CAREER: "Carrière",
}

const ARENAS := [
	{"id": &"kinshasa_ring", "name": "Ring populaire de Kinshasa", "available": true},
	{"id": &"quartier", "name": "Terrain de quartier", "available": false},
	{"id": &"marche", "name": "Marché congolais", "available": false},
	{"id": &"fleuve", "name": "Arène du fleuve Congo", "available": false},
	{"id": &"village", "name": "Village traditionnel", "available": false},
	{"id": &"stade_nuit", "name": "Stade de nuit", "available": false},
	{"id": &"foret", "name": "Arène mystique de la forêt", "available": false},
	{"id": &"urbain", "name": "Terrain urbain abandonné", "available": false},
]

const SAVE_PATH := "user://progress.cfg"

var mode: int = Mode.QUICK
var p1_id: StringName = &"mokonzi"
var p2_id: StringName = &"nkosi"
var p1_costume := 0
var p2_costume := 0
var arena_id: StringName = &"kinshasa_ring"
var rounds_to_win := 2

# Progression de session (tournoi / survie)
var run_stage := 0
var run_wins := 0
var carry_hp_ratio := 1.0

# Progression sauvegardée
var unlocks: Dictionary = {}
var stats: Dictionary = {"fights": 0, "wins": 0, "survival_best": 0, "tournaments": 0}

## Résultat du dernier combat (lu par l'écran de résultats).
var last_result: Dictionary = {}

func _ready() -> void:
	load_progress()

func is_unlocked(key: String) -> bool:
	return key == "" or unlocks.get(key, false)

func unlock(key: String) -> bool:
	if unlocks.get(key, false):
		return false
	unlocks[key] = true
	save_progress()
	return true

func available_costumes(data: FighterData) -> Array[int]:
	var out: Array[int] = []
	for i in data.costumes.size():
		if is_unlocked(data.costumes[i].get("unlock", "")):
			out.append(i)
	return out

func difficulty_for_run() -> int:
	match mode:
		Mode.TOURNAMENT:
			return clampi(Settings.difficulty + run_stage - 1, 0, 3)
		Mode.SURVIVAL:
			return clampi(Settings.difficulty + int(run_wins / 3), 0, 3)
	return Settings.difficulty

func start_run(m: int) -> void:
	mode = m
	run_stage = 0
	run_wins = 0
	carry_hp_ratio = 1.0

## Adversaire suivant dans un tournoi / survie (alterne les combattants jouables).
func next_opponent() -> StringName:
	var pool := Roster.playable()
	var candidates: Array[FighterData] = []
	for f in pool:
		if f.id != p1_id:
			candidates.append(f)
	if candidates.is_empty():
		candidates = pool
	return candidates[(run_stage + run_wins) % candidates.size()].id

func save_progress() -> void:
	var c := ConfigFile.new()
	c.set_value("progress", "unlocks", unlocks)
	c.set_value("progress", "stats", stats)
	c.save(SAVE_PATH)

func load_progress() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) == OK:
		unlocks = c.get_value("progress", "unlocks", {})
		var s: Dictionary = c.get_value("progress", "stats", {})
		stats.merge(s, true)
