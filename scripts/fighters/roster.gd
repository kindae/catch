## Registre des combattants. Pour ajouter un combattant : créer son script
## (fonction statique create() -> FighterData) et l'ajouter à SCRIPTS.
class_name Roster
extends RefCounted

const SCRIPTS := [
	"res://scripts/fighters/mokonzi.gd",
	"res://scripts/fighters/nkosi.gd",
	"res://scripts/fighters/upcoming.gd",
]

static var _cache: Array[FighterData] = []

static func all() -> Array[FighterData]:
	if _cache.is_empty():
		for path in SCRIPTS:
			var s: GDScript = load(path)
			var r = s.call(&"create")
			if r is FighterData:
				_cache.append(r)
			elif r is Array:
				for f in r:
					_cache.append(f)
	return _cache

static func playable() -> Array[FighterData]:
	var out: Array[FighterData] = []
	for f in all():
		if f.playable:
			out.append(f)
	return out

static func by_id(id: StringName) -> FighterData:
	for f in all():
		if f.id == id:
			return f
	return all()[0]
