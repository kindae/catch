## Nkosi — « L'Éclair de Matonge ». Rapide et agile.
extends RefCounted

static func create() -> FighterData:
	var d := FighterData.new()
	d.id = &"nkosi"
	d.display_name = "Nkosi"
	d.epithet = "L'Éclair de Matonge"
	d.style = "Rapide et agile"
	d.description = "Danseur devenu catcheur, il enchaîne les coups et lance des éclairs d'énergie."
	d.max_hp = 92.0
	d.walk_speed = 3.0
	d.back_speed = 2.6
	d.side_speed = 2.6
	d.power_mult = 0.95
	d.defense_mult = 1.05
	d.jump_velocity = 7.2
	d.stat_display = {"puissance": 3, "vitesse": 5, "défense": 2, "mystique": 4}
	d.height = 0.98
	d.bulk = 0.9
	d.skin_color = Color(0.42, 0.26, 0.16)
	d.costumes = BaseMoves.default_costumes(Color(0.05, 0.5, 0.92), Color(0.97, 0.84, 0.1), Color(0.95, 0.95, 0.98), Color(0.8, 0.07, 0.09))
	d.mask = true
	d.headband = false
	d.hair_style = 2
	d.necklace = true
	d.paint_color = Color(0.98, 0.85, 0.2)
	d.paint_pattern = 2
	d.moves = BaseMoves.build()
	for k in [&"jab", &"cross", &"kick_mid"]:
		d.moves[k].startup -= 1
		d.moves[k].recovery -= 2
	d.moves[&"spin_kick"].display_name = "Tornade de Matonge"
	d.moves[&"spin_kick"].startup = 12
	var p := PowerData.new()
	p.id = &"eclair"
	p.display_name = "Éclair mystique"
	p.kind = PowerData.Kind.ORB
	p.energy_cost = 20.0
	p.cooldown = 200
	p.startup = 13
	p.recovery = 20
	p.damage = 10.0
	p.speed = 12.0
	p.range_m = 9.0
	p.width = 0.35
	p.color = Color(0.35, 0.75, 1.0)
	p.counter_hint = "Projectile à hauteur de poitrine : esquive latérale ou blocage."
	d.power = p
	d.transform_name = "Esprit de l'Orage"
	d.aura_color = Color(0.3, 0.7, 1.0)
	d.transform_eye_color = Color(0.7, 0.95, 1.0)
	d.ultimate_name = "Mille Éclairs"
	d.ultimate_damage = 32.0
	d.finisher_name = "Orage sur le Fleuve"
	d.intro_anim = &"intro_dance"
	d.victory_anim = &"victory_sky"
	d.intro_line = "Trop rapide pour toi !"
	return d
