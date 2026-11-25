# Rapport — Prototype jouable v0.1.0

Date : 25/11/2026 — Godot 4.4.1-stable, GDScript.

## 1. Ce qui est livré

- Combat 1 contre 1 complet en 3D : Mokonzi (puissant, équilibré) contre Nkosi (rapide, agile),
  ou miroir ; contre l'IA (4 niveaux) ou en entraînement.
- Système de combat : poings, pieds, enchaînements (strings), coups lourds, attaques aériennes,
  saut, pas de côté, esquive invulnérable, garde, contre (parade sur 6 frames), contre-attaque
  après esquive, coup de contre, prises (Body Slam) et projection (Projection du Fleuve) avec
  dégagement, tombé 1-2-3, projectiles mystiques, transformation, charge ultime, technique de
  finition (sans gore), endurance (garde brisée, épuisement), énergie mystique, hitstop, ralentis.
- Ring populaire de Kinshasa : tapis aux couleurs du drapeau, cordes rouge-jaune-bleu, tablier en
  wax, barrières publicitaires fictives, tribunes, foule animée (MultiMesh), guirlandes, portique
  d'éclairage, immeubles et palmiers, ambiance sonore et musique synthétisées.
- Interface : menu principal, sélection (8 fiches dont 6 verrouillées), 3 tenues par combattant
  (1 à débloquer), options (profils graphiques, 30/60 FPS, résolution adaptative, commandes,
  volumes), pause avec guide des commandes, résultats, modes Tournoi (3 combats) et Survie.
- Export : `build/catch243-debug.apk` (debug, arm64-v8a + armeabi-v7a, 52 Mo, signatures v2/v3
  vérifiées) et `build/catch243-release.aab` (Gradle, 49 Mo, clé de test locale).

## 2. Performances réellement mesurées

**Important : aucun téléphone ni émulateur GPU n'était disponible dans l'environnement de
développement.** Les chiffres ci-dessous proviennent d'un serveur Linux sans carte graphique
(rendu 100 % logiciel par le processeur : Mesa llvmpipe / lavapipe, 4 cœurs x86). Les FPS ne
sont donc **pas** représentatifs d'un téléphone ; les nombres de draw calls, de triangles, la
mémoire et le coût de la logique le sont beaucoup plus.

### Logique de combat (`--selftest`, sans rendu)

| Mesure | Valeur |
|---|---|
| Combats simulés IA contre IA | 24 combats complets + 3 min d'entraînement, 0 anomalie |
| Coût moyen d'un tick logique (2 combattants + IA + projectiles) | ≈ 26 µs (x86) |
| Pire tick observé | 1,6 à 2,4 ms (premiers ticks, chargement) |
| Maître contre Facile | 6 victoires sur 6 pour le Maître |
| Facile contre Maître | 0 victoire sur 6 |
| Difficile contre Difficile | 4-2 ; parades 19, prises 22 |

Le budget d'une frame à 60 FPS est de 16,7 ms : la logique en consomme < 0,2 % sur x86 ; même
10 fois plus lente sur un téléphone d'entrée de gamme, elle resterait < 2 %.

### Rendu (`--benchmark 20`, 1280×720, combat IA contre IA)

| Renderer | Profil | Échelle 3D | Draw calls (3D / 2D) | Triangles | FPS (rendu CPU) | Mémoire statique / vidéo |
|---|---|---|---|---|---|---|
| Compatibility (OpenGL) | Faible | 0,60 | 139 (117 / 13) | 54 k | 27,8 | 59 / 40 Mo |
| Compatibility (OpenGL) | Moyen | 0,80 | 213 (197 / 15) | 101 k | 15,0 | 60 / 51 Mo |
| Compatibility (OpenGL) | Élevé | 0,92 | 212 (203 / 13) | 115 k | 15,0 | 60 / 54 Mo |
| Compatibility (OpenGL) | Ultra | 1,00 | 215 (193 / 27) | 136 k | 15,0 | 60 / 69 Mo |
| **Mobile (Vulkan)** | Moyen | 0,80 | 218 (121 3D + 94 ombres / 29) | — | 15,1 | — |

Optimisations faites pendant le prototype, grâce à ces mesures :

| Problème mesuré | Correction | Avant → après |
|---|---|---|
| Texte et jauges du HUD dessinés primitive par primitive | Jauges dans un seul shader, textes en Label | 427 → 13 draw calls 2D |
| Décor fait de centaines de boîtes | Fusion des maillages statiques par matériau | inclus dans le total ci-dessous |
| Pièces du corps séparées | Fusion par articulation et par matériau | inclus dans le total ci-dessous (123 objets 3D visibles au total après fusion) |
| Passes de lumière supplémentaires (renderer OpenGL) | 1 seule lumière dynamique en Compatibility | — |
| Total en profil Moyen (renderer OpenGL) | | 770 → 213 draw calls |

### Ce qu'il reste à mesurer sur de vrais téléphones

Installer l'APK sur au moins trois appareils (entrée de gamme Mali/Adreno 5xx, milieu de gamme,
haut de gamme), activer *Options → Afficher les FPS*, puis relever FPS, température et autonomie
pour chaque profil. La commande `--benchmark` peut être passée via `command_line/extra_args` du
préréglage d'export pour automatiser ces mesures.

## 3. Ressources manquantes

| Ressource | État actuel | Nécessaire pour la version finale |
|---|---|---|
| Modèles 3D des combattants | Modèles procéduraux (formes organiques générées par le code) | Modèles semi-réalistes GLB riggés (8 combattants), textures PBR peau/tenues, LOD |
| Animations | Poses clés écrites en code (≈ 60 animations) | Animations capturées ou faites à la main (mocap), animations faciales |
| Arènes | 1 arène procédurale | 7 arènes modélisées, éclairage précalculé (lightmaps) |
| Audio | Sons et musique synthétisés par le code | Musique originale (rumba/ndombolo), bruitages enregistrés, voix du présentateur |
| Interface | Police par défaut de Godot, aucun portrait | Police sous licence, portraits, icônes, logo |
| Personnages 3 à 8 | Fiches de données uniquement | Conception, modèles, coups, pouvoirs (bouclier, téléportation, illusions, esprit, rayon) |

Le pipeline d'import est prêt : `FighterData.model_scene_path` accepte un GLB/FBX à squelette
humanoïde ; les noms d'os Mixamo/Unreal sont reconnus (`FighterRig.GLB_BONES`). **Ce chemin n'a
pas pu être testé faute de modèle.**

## 4. Limitations techniques connues

- Les personnages du prototype restent stylisés : ils ne respectent pas encore l'objectif
  « semi-réaliste » de la version finale.
- Pas de cinématique inverse : les pieds peuvent légèrement glisser ou flotter.
- Hitboxes définies par les données de coups (précises et déterministes) et non attachées aux os.
- L'éclairage précalculé (lightmaps) n'est pas utilisé : il nécessite un décor statique importé
  et un passage dans l'éditeur. Les décors lointains utilisent des matériaux non éclairés.
- Le mode Carrière n'est pas implémenté (bouton désactivé). Tournoi et Survie sont jouables.
- APK de debug universel : 52 Mo (deux architectures). Un APK arm64 seul ou l'AAB réduit la taille
  téléchargée (environ 25 à 30 Mo).
- L'AAB est signé avec une clé de test générée localement (non versionnée) : il faut une clé de
  production pour le Play Store.

## 5. Prochaines étapes proposées

1. Tester l'APK sur de vrais téléphones et calibrer les profils graphiques par défaut.
2. Ajuster l'équilibrage (dégâts, frame data) après des parties avec de vrais joueurs.
3. Produire ou acheter les deux premiers modèles GLB riggés, puis les brancher via `model_scene_path`.
4. Ajouter les combattants 3 et 4 (Kimbangu : invocation d'esprit ; Mamba : augmentation de puissance).
5. Deuxième arène (Marché congolais) avec lightmaps.
6. Mode Carrière.
