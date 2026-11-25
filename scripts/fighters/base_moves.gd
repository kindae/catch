## Jeu de coups commun. Chaque combattant part de cette base et la
## personnalise (dégâts, vitesse, noms) dans son propre script.
class_name BaseMoves
extends RefCounted

static func _m(d: Dictionary) -> MoveData:
	var m := MoveData.new()
	for k in d:
		m.set(k, d[k])
	return m

static func build() -> Dictionary:
	var moves := {}
	moves[&"jab"] = _m({"id": &"jab", "display_name": "Direct", "anim": &"jab",
		"startup": 6, "active": 2, "recovery": 11, "damage": 6.0, "stamina_cost": 3.0,
		"hit_stun": 16, "block_stun": 9, "push": 0.18, "hitbox_offset": Vector3(-0.08, 1.5, -0.78),
		"hitbox_radius": 0.2, "lunge": 0.12, "hitstop": 4, "shake": 0.08,
		"chain": {&"punch": &"cross", &"kick": &"kick_mid"}})
	moves[&"cross"] = _m({"id": &"cross", "display_name": "Crochet", "anim": &"cross",
		"startup": 8, "active": 3, "recovery": 14, "damage": 8.0, "stamina_cost": 4.0,
		"hit_stun": 18, "block_stun": 10, "push": 0.22, "hitbox_offset": Vector3(0.06, 1.48, -0.8),
		"hitbox_radius": 0.22, "lunge": 0.15, "hitstop": 5, "shake": 0.1,
		"chain": {&"punch": &"uppercut", &"kick": &"kick_high"}})
	moves[&"uppercut"] = _m({"id": &"uppercut", "display_name": "Uppercut", "anim": &"uppercut",
		"startup": 11, "active": 3, "recovery": 22, "damage": 11.0, "stamina_cost": 6.0,
		"hit_stun": 24, "block_stun": 12, "push": 0.4, "hitbox_offset": Vector3(0.05, 1.45, -0.7),
		"hitbox_radius": 0.25, "lunge": 0.2, "launches": true, "launch_velocity": Vector3(0, 6.0, 2.2),
		"hitstop": 8, "shake": 0.3})
	moves[&"kick_mid"] = _m({"id": &"kick_mid", "display_name": "Coup de pied", "anim": &"kick_mid",
		"startup": 10, "active": 3, "recovery": 16, "damage": 10.0, "stamina_cost": 5.0,
		"hit_stun": 20, "block_stun": 12, "push": 0.35, "hitbox_offset": Vector3(0.08, 1.05, -0.9),
		"hitbox_radius": 0.25, "lunge": 0.1, "hitstop": 6, "shake": 0.15,
		"chain": {&"kick": &"kick_high"}})
	moves[&"kick_high"] = _m({"id": &"kick_high", "display_name": "Pied retourné", "anim": &"kick_high",
		"startup": 13, "active": 3, "recovery": 20, "damage": 13.0, "stamina_cost": 7.0,
		"hit_stun": 24, "block_stun": 14, "push": 0.5, "hitbox_offset": Vector3(0.1, 1.55, -0.88),
		"hitbox_radius": 0.27, "lunge": 0.15, "launches": true, "launch_velocity": Vector3(0, 4.5, 3.6),
		"hitstop": 8, "shake": 0.3})
	moves[&"heavy"] = _m({"id": &"heavy", "display_name": "Marteau", "anim": &"heavy",
		"startup": 16, "active": 4, "recovery": 22, "damage": 15.0, "stamina_cost": 9.0,
		"hit_stun": 26, "block_stun": 16, "push": 0.5, "hitbox_offset": Vector3(0, 1.35, -0.85),
		"hitbox_radius": 0.3, "lunge": 0.55, "launches": true, "launch_velocity": Vector3(0, 3.5, 3.0),
		"hitstop": 9, "shake": 0.4})
	moves[&"spin_kick"] = _m({"id": &"spin_kick", "display_name": "Pied tournoyant", "anim": &"spin_kick",
		"startup": 14, "active": 4, "recovery": 20, "damage": 14.0, "stamina_cost": 9.0,
		"hit_stun": 24, "block_stun": 14, "push": 0.6, "hitbox_offset": Vector3(0, 1.25, -0.92),
		"hitbox_radius": 0.3, "lunge": 0.35, "launches": true, "launch_velocity": Vector3(0, 4.0, 4.2),
		"hitstop": 8, "shake": 0.35})
	moves[&"air_kick"] = _m({"id": &"air_kick", "display_name": "Coup de pied sauté", "anim": &"air_kick",
		"startup": 5, "active": 40, "recovery": 10, "damage": 11.0, "stamina_cost": 6.0,
		"hit_stun": 22, "block_stun": 12, "push": 0.5, "hitbox_offset": Vector3(0, 0.75, -0.7),
		"hitbox_radius": 0.3, "aerial": true, "launches": true, "launch_velocity": Vector3(0, 3.0, 3.5),
		"hitstop": 7, "shake": 0.3})
	moves[&"air_elbow"] = _m({"id": &"air_elbow", "display_name": "Coude plongeant", "anim": &"air_elbow",
		"startup": 6, "active": 40, "recovery": 10, "damage": 9.0, "stamina_cost": 5.0,
		"hit_stun": 22, "block_stun": 12, "push": 0.3, "hitbox_offset": Vector3(0, 1.05, -0.55),
		"hitbox_radius": 0.3, "aerial": true, "hitstop": 6, "shake": 0.2})
	return moves

static func default_costumes(main: Color, second: Color, boots: Color, accent: Color) -> Array[Dictionary]:
	var c: Array[Dictionary] = []
	c.append({"name": "Tenue officielle", "trunks": main, "trunks2": second, "boots": boots, "accent": accent, "pattern": 0, "unlock": ""})
	c.append({"name": "Tenue de quartier", "trunks": second.darkened(0.15), "trunks2": main.lightened(0.1), "boots": Color(0.12, 0.12, 0.14), "accent": main, "pattern": 1, "unlock": ""})
	c.append({"name": "Tenue de champion", "trunks": Color(0.95, 0.78, 0.2), "trunks2": Color(0.1, 0.1, 0.12), "boots": Color(0.95, 0.78, 0.2), "accent": Color(1, 1, 1), "pattern": 2, "unlock": "tournament_win"})
	return c
