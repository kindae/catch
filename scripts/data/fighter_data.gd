## Définition complète d'un combattant : statistiques, apparence, coups,
## pouvoir mystique, transformation, ultime, entrée et victoire.
## Ajouter un combattant = créer un script dans scripts/fighters/ et l'enregistrer
## dans Roster.
class_name FighterData
extends Resource

@export var id: StringName
@export var display_name := ""
@export var epithet := ""
@export var description := ""
@export var style := ""
@export var playable := true
@export var unlock_hint := ""

# --- Statistiques ---
@export var max_hp := 100.0
@export var max_stamina := 100.0
@export var walk_speed := 2.6
@export var back_speed := 2.2
@export var side_speed := 2.1
@export var power_mult := 1.0
@export var defense_mult := 1.0
@export var jump_velocity := 6.6
## Valeurs 0..5 pour l'écran de sélection.
@export var stat_display := {"puissance": 3, "vitesse": 3, "défense": 3, "mystique": 3}

# --- Apparence (modèle procédural ou scène GLB) ---
## Chemin optionnel vers un modèle GLB/FBX importé (squelette humanoïde).
## Vide = modèle procédural FighterRig.
@export var model_scene_path := ""
@export var height := 1.0
@export var bulk := 1.0
@export var skin_color := Color(0.36, 0.22, 0.14)
@export var costumes: Array[Dictionary] = []
@export var mask := false
@export var headband := true
@export var hair_style := 0
@export var beard := false
@export var necklace := true
@export var raffia_skirt := false
@export var shoulder_pads := false
@export var paint_color := Color(0.95, 0.92, 0.85)
@export var paint_pattern := 1
@export var eye_color := Color(0.15, 0.1, 0.08)

# --- Coups ---
@export var moves: Dictionary = {}

# --- Mystique ---
@export var power: PowerData
@export var transform_name := ""
@export var transform_frames := 720
@export var transform_damage_mult := 1.25
@export var transform_speed_mult := 1.2
@export var aura_color := Color(1.0, 0.6, 0.1)
@export var transform_eye_color := Color(1.0, 0.85, 0.2)
@export var ultimate_name := ""
@export var ultimate_damage := 34.0
@export var finisher_name := ""

# --- Présentation ---
@export var intro_anim: StringName = &"intro_flex"
@export var victory_anim: StringName = &"victory_arms"
@export var intro_line := ""

func costume(i: int) -> Dictionary:
	if costumes.is_empty():
		return {}
	return costumes[clampi(i, 0, costumes.size() - 1)]

func move(id_: StringName) -> MoveData:
	return moves.get(id_)
