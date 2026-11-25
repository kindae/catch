## Mokonzi — « Le Chef du Ring ». Puissant et équilibré.
extends RefCounted

static func create() -> FighterData:
	var d := FighterData.new()
	d.id = &"mokonzi"
	d.display_name = "Mokonzi"
	d.epithet = "Le Chef du Ring"
	d.style = "Puissant et équilibré"
	d.description = "Colosse de Kinshasa, il frappe lourd et protège son quartier. Son Onde de choc fend le tapis."
	d.max_hp = 110.0
	d.walk_speed = 2.45
	d.back_speed = 2.05
	d.side_speed = 2.0
	d.power_mult = 1.12
	d.defense_mult = 0.92
	d.stat_display = {"puissance": 5, "vitesse": 3, "défense": 4, "mystique": 3}
	d.height = 1.04
	d.bulk = 1.18
	d.skin_color = Color(0.27, 0.16, 0.1)
	d.costumes = BaseMoves.default_costumes(Color(0.8, 0.07, 0.09), Color(0.97, 0.84, 0.1), Color(0.75, 0.06, 0.08), Color(0.97, 0.84, 0.1))
	d.headband = true
	d.hair_style = 1
	d.beard = true
	d.necklace = true
	d.shoulder_pads = true
	d.paint_color = Color(0.95, 0.93, 0.86)
	d.paint_pattern = 1
	d.moves = BaseMoves.build()
	d.moves[&"heavy"].display_name = "Marteau de Kin"
	d.moves[&"heavy"].damage = 17.0
	d.moves[&"uppercut"].damage = 12.0
	d.moves[&"jab"].startup = 7
	var p := PowerData.new()
	p.id = &"onde_de_choc"
	p.display_name = "Onde de choc"
	p.kind = PowerData.Kind.SHOCKWAVE
	p.energy_cost = 25.0
	p.cooldown = 240
	p.startup = 16
	p.recovery = 24
	p.damage = 13.0
	p.speed = 8.5
	p.range_m = 7.5
	p.width = 0.6
	p.color = Color(1.0, 0.5, 0.08)
	p.counter_hint = "Rampe au sol : sautez ou esquivez sur le côté. Blocable (dégâts réduits)."
	d.power = p
	d.transform_name = "Couronne de Feu"
	d.aura_color = Color(1.0, 0.45, 0.05)
	d.transform_eye_color = Color(1.0, 0.8, 0.15)
	d.ultimate_name = "Colère du Mokonzi"
	d.ultimate_damage = 36.0
	d.finisher_name = "Le Trône de Kinshasa"
	d.intro_anim = &"intro_flex"
	d.victory_anim = &"victory_chief"
	d.intro_line = "Ici, c'est mon quartier !"
	return d
