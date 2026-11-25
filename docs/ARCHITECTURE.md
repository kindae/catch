# Architecture technique — Catch 243

## Principe : logique séparée du rendu

```
 FighterCmd ──► Fighter.tick()  (60 Hz fixes, frame data)  ──►  état exposé
 (joueur / IA)        │                                         anim, anim_frame,
                      ▼                                         anim_marks, transformed
                 Match (arbitre)                                       │
   contacts hitbox/hurtbox, prises synchronisées,                      ▼
   projectiles, manches, chrono, ralentis, caméra          FighterRig (rendu seul)
                                                           poses, matériaux, aura
```

- `Fighter` (`scripts/combat/fighter.gd`) : machine à états (IDLE, WALK, JUMP, ATTACK, BLOCK,
  HITSTUN, KNOCKDOWN, GRAB_ATK/GRABBED, CAST, TRANSFORM, PIN…), ressources (vie, endurance,
  énergie mystique), tampon d'entrées (8 frames), annulations / enchaînements.
- `Match` (`scripts/combat/match.gd`) : résout les contacts. Les **hurtboxes** sont des capsules
  (corps + tête, réduites pendant l'esquive, horizontales au sol), les **hitboxes** des sphères
  définies dans le repère local de l'attaquant (`MoveData.hitbox_offset`). Test exact
  sphère-segment. Gère garde, contre (fenêtre de 6 frames), coup de contre (adversaire en
  startup), contre-attaque après esquive, échanges simultanés, hitstop, mise à l'échelle des combos.
- `Match.step()` fonctionne **sans aucun nœud visuel** : `--selftest` simule des dizaines de combats.

## Synchronisation des animations

- Les animations (`AnimLib`) sont des poses clés exprimées en frames. Chaque animation de coup
  porte des « marques » (fin du startup, fin de la phase active, fin) ; le rig recale l'animation
  sur la frame data réelle du coup (`Fighter.anim_marks`). Modifier la vitesse d'un coup pour un
  personnage ne désynchronise donc jamais l'image et la hitbox.
- Prises et ultime (`GrabLib`) : l'attaquant pilote la position du défenseur à chaque frame
  (courbe de distance) et lui impose la même frame d'animation (`slam_atk` / `slam_def`, etc.).
  Les deux corps restent calés, y compris pendant les ralentis.
- Le rendu interpole entre deux ticks logiques (`FighterRig`), ce qui garde l'image fluide en
  ralenti (`Engine.time_scale`) ou à 30 FPS.

## Ajouter un combattant

1. Créer `scripts/fighters/<nom>.gd` avec `static func create() -> FighterData` (voir `mokonzi.gd`).
   Partir de `BaseMoves.build()` puis ajuster dégâts / vitesses / noms.
2. Définir l'apparence (`height`, `bulk`, couleurs de peau, `costumes`, masque, peintures…) ou
   renseigner `model_scene_path` vers un **GLB/FBX** à squelette humanoïde (noms d'os Mixamo /
   Unreal reconnus, voir `FighterRig.GLB_BONES`).
3. Définir `power` (`PowerData` : coût, recharge, vitesse, largeur, indice de parade),
   transformation (nom, durée, multiplicateurs, couleur d'aura), ultime et finition.
4. Ajouter le chemin dans `Roster.SCRIPTS`. `--selftest` vérifie automatiquement les références
   d'animations et d'enchaînements.

Les six combattants prévus (Kimbangu, Mamba, Nzambe ya Ring, Fantôme de Kin, Tonnerre du Congo,
Léopard Noir) ont déjà leur fiche (`upcoming.gd`) et apparaissent verrouillés.

## Pouvoirs mystiques

`PowerData.Kind` prévoit : onde de choc, orbe, téléportation, bouclier, aura de feu,
augmentation de puissance, illusions, invocation d'esprit, rayon. Dans le prototype, **onde de
choc** (au sol : se saute ou s'esquive latéralement, blocable) et **orbe** (à hauteur de poitrine :
pas de côté ou garde) sont implémentés. Chaque pouvoir a un coût, une recharge (`cooldown`), une
phase de lancement vulnérable et une parade ; deux projectiles qui se croisent s'annulent.

## Transformation

Aucun changement de modèle : la transformation active une coque d'aura (`aura.gdshader`, en
`next_pass` des matériaux existants), l'émission des yeux, la lueur des peintures corporelles et
un émetteur de particules. Effets de jeu : ×1,25 dégâts, ×1,2 vitesse, pouvoir amplifié, accès à
l'ultime. Durée limitée (12 s) ; l'ultime consomme la transformation.

## Rendu et optimisation

- Renderer **Mobile** (Vulkan) avec repli automatique **Compatibility** (OpenGL ES 3) sur les
  appareils sans Vulkan (`rendering_device/fallback_to_opengl3`).
- Profils Faible / Moyen / Élevé / Ultra (`Settings.PROFILES`) : échelle 3D, MSAA, ombres,
  bloom, brouillard, densité de foule, particules, nombre de lumières, coque d'aura.
- Résolution interne adaptative (baisse de 5 % si le budget de frame est dépassé, remonte ensuite).
- 60 FPS par défaut, mode économie 30 FPS, jeu suspendu en arrière-plan (pause + son coupé).
- Foule : **un seul MultiMesh** animé dans le vertex shader (une draw call).
- Effets : pools de particules, anneaux, sphères (aucune allocation en combat).
- Maillages procéduraux mis en cache et partagés ; décors lointains non éclairés.
- Lumières : 2 directionnelles (une seule avec ombres) + 1 spot sans ombre + 1 lumière d'impact
  (profil Élevé et plus).
