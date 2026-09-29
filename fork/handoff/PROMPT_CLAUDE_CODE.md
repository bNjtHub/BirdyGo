# Message à donner à Claude Code

Copie ce dossier `design_handoff_birdygo_homogeneite/` à la racine du dépôt (par exemple dans `fork/handoff/`), puis envoie ce message :

---

Lis `CLAUDE.md`, `fork/DESIGN.md` et `fork/handoff/design_handoff_birdygo_homogeneite/README.md`.

Ce handoff décrit la **J6h, passe d'homogénéité** : aligner tous les écrans sur la ligne Profil / Quiz et ajouter quelques nouveautés. Les fichiers `maquettes/*.dc.html` sont des références visuelles, pas du code à copier.

1. Commence en **mode plan**. Pour chaque écran de la section 2 du README, liste les fichiers créés et modifiés, les tests prévus dans `test/fork/` et les risques. Attends ma validation avant d'écrire du code.
2. Ajoute d'abord la section « Ligne J6h » (section 1 du README) dans `fork/DESIGN.md`, et un jalon J6h dans `fork/PLAN.md`, avec une case par écran.
3. Travaille ensuite **un écran = une PR**, dans cet ordre :
   1. socle : `SpeciesAvatar` avec la silhouette, les pastilles, `AppIcons`, le jeton #8CD3D9 et l'aile ;
   2. Accueil, avec la bande « Ta journée » et son tiroir ;
   3. Écoute, avec le thème clair et les étiquettes de rareté ;
   4. Bilan ;
   5. Carnet ;
   6. Fiche ;
   7. Profil ;
   8. Quiz ;
   9. Palmarès ;
   10. Sonothèque ;
   11. Réglages, avec le prénom ;
   12. Menu Plus ;
   13. Objectif ;
   14. Carte ;
   15. Revue ;
   16. Premier lancement.

   Titre de PR : « J6h <Écran> : … ».
4. Règles :
   - Aucune couleur ni taille en dur : uniquement les jetons `birdy_tokens.dart` et `birdy_typography.dart`. Crée un jeton s'il en manque un.
   - Nouvelles chaînes en français et en anglais dans les `.arb`.
   - Icônes via `AppIcons`.
   - Garde les squelettes et `BirdyCrossFade` sur chaque bloc modifié.
   - Zones à toucher d'au moins 48, et vérifie le contraste AA avec `test/fork/design/contrast_test.dart`.
   - Alignement sur la ligne de base pour chiffre + libellé.
5. Pour les calculs d'heures (heure dorée, heures des oiseaux), mets les écarts dans une config du fork, pas en dur.
6. « Me le rappeler » a besoin de notifications locales : dis-moi si la dépendance n'est pas prévue, avant de l'ajouter.

Réponses courtes, en français.
