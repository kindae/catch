## Combattants prévus (fiches prêtes, modèles et animations à produire).
## Ils apparaissent verrouillés dans l'écran de sélection.
extends RefCounted

static func _f(id: StringName, name: String, epithet: String, style: String, desc: String,
		stats: Dictionary, power_name: String, kind: PowerData.Kind, color: Color,
		transform: String, finisher: String) -> FighterData:
	var d := FighterData.new()
	d.id = id
	d.display_name = name
	d.epithet = epithet
	d.style = style
	d.description = desc
	d.stat_display = stats
	d.playable = false
	d.unlock_hint = "En développement"
	d.moves = BaseMoves.build()
	var p := PowerData.new()
	p.id = StringName(power_name.to_lower())
	p.display_name = power_name
	p.kind = kind
	p.color = color
	p.implemented = false
	d.power = p
	d.aura_color = color
	d.transform_name = transform
	d.finisher_name = finisher
	return d

static func create() -> Array:
	return [
		_f(&"kimbangu", "Kimbangu", "Gardien des Ancêtres", "Énergie mystique",
			"Guerrier fictif qui canalise l'énergie mystique de la forêt et invoque un esprit protecteur.",
			{"puissance": 3, "vitesse": 3, "défense": 3, "mystique": 5}, "Invocation de l'Esprit", PowerData.Kind.SPIRIT,
			Color(0.6, 1.0, 0.5), "Souffle des Ancêtres", "Le Cercle Sacré"),
		_f(&"mamba", "Mamba", "Le Serpent de Ndjili", "Attaques rapides",
			"Spécialiste des attaques éclair et des enchaînements venimeux.",
			{"puissance": 2, "vitesse": 5, "défense": 2, "mystique": 3}, "Venin d'énergie", PowerData.Kind.POWER_UP,
			Color(0.4, 1.0, 0.3), "Mue du Mamba", "Morsure Finale"),
		_f(&"nzambe_ya_ring", "Nzambe ya Ring", "La Montagne", "Lourd et résistant",
			"Poids lourd quasi immobile, il encaisse tout et protège avec un bouclier mystique.",
			{"puissance": 5, "vitesse": 1, "défense": 5, "mystique": 2}, "Bouclier mystique", PowerData.Kind.SHIELD,
			Color(0.9, 0.85, 0.6), "Peau de Pierre", "Tremblement de Terre"),
		_f(&"fantome_de_kin", "Fantôme de Kin", "L'Insaisissable", "Esquives et illusions",
			"Ombre des nuits de Kinshasa, il crée des illusions et disparaît au dernier moment.",
			{"puissance": 2, "vitesse": 4, "défense": 3, "mystique": 5}, "Illusions", PowerData.Kind.ILLUSION,
			Color(0.75, 0.6, 1.0), "Voile de Brume", "Disparition"),
		_f(&"tonnerre_du_congo", "Tonnerre du Congo", "La Foudre du Fleuve", "Attaques électriques",
			"Ses poings chargés d'électricité grondent comme l'orage au-dessus du fleuve.",
			{"puissance": 4, "vitesse": 3, "défense": 3, "mystique": 4}, "Rayon de foudre", PowerData.Kind.BEAM,
			Color(0.95, 0.95, 0.3), "Cœur d'Orage", "Le Grand Tonnerre"),
		_f(&"leopard_noir", "Léopard Noir", "Le Chasseur", "Agressif et acrobatique",
			"Acrobate redoutable, il bondit et frappe depuis les cordes.",
			{"puissance": 4, "vitesse": 4, "défense": 2, "mystique": 3}, "Bond de l'ombre", PowerData.Kind.TELEPORT,
			Color(1.0, 0.3, 0.2), "Instinct du Fauve", "Griffe de Minuit"),
	]
