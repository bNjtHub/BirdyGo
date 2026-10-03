# Politique de confidentialité de BirdyGo

**Dernière mise à jour :** [DATE]

> Brouillon adapté de la politique de BirdNET Live (`docs/privacy.fr.md`). À héberger à une adresse web
> publique avant de la renseigner dans la Play Console. Remplir les champs entre crochets et relire
> après tout changement des fonctions réseau. Supprimer cet encadré avant publication.
>
> **Points non vérifiés (à contrôler avant publication) :**
> - Sauvegarde Android : le manifeste ne fixe pas `allowBackup`, donc la sauvegarde automatique vers le
>   compte Google de l'utilisateur est active par défaut ; elle peut inclure sessions, positions et
>   extraits audio. La section « Conservation » la mentionne ; à confirmer ou à désactiver.
> - Les durées de conservation des services tiers (OSM, IGN, Open-Meteo, iNaturalist) ne sont pas
>   reprises (les 90 jours d'Open-Meteo viennent de la politique upstream).
> - Le lien « Politique de confidentialité » de l'écran À propos pointe encore vers le site upstream.

Cette politique s'applique à **BirdyGo** (l'**application**, identifiant `fr.justcodeit.birdygo`), un fork
indépendant de BirdNET Live. L'application est publiée par [NOM DU DÉVELOPPEUR] (**nous**).

| | |
|---|---|
| **Application** | BirdyGo |
| **Développeur** | [NOM / RAISON SOCIALE] |
| **Contact confidentialité** | [ADRESSE E-MAIL] |

## En bref

- L'analyse des chants se fait **entièrement sur votre appareil**. Aucun enregistrement n'est envoyé.
- Pas de compte, pas de publicité, pas d'outil d'analyse d'audience, pas de suivi, pas de rapport de
  plantage automatique.
- Nous n'exploitons aucun serveur qui reçoive vos données.
- Certaines fonctions facultatives (cartes, nom de lieu, météo, photos en grand format) contactent des
  services tiers. Elles sont **désactivées par défaut** et vous les activez une à une.

## Traitement sur l'appareil

Le microphone sert à identifier les oiseaux avec deux modèles exécutés localement : un classificateur
audio BirdNET+ et un géomodèle qui estime quelles espèces sont probables à votre position et à cette
période. Aucune donnée audio n'est transmise à un serveur.

## Données enregistrées sur votre appareil

| Donnée | Utilité | Stockage |
|---|---|---|
| Extraits audio des détections | Réécoute, quiz, export | Fichiers locaux |
| Résultats (espèces, score, date, heure, statut de revue) | Carnet, statistiques, progression | Fichiers de session locaux et index local |
| Position GPS | Marquage des détections, carte, géomodèle | Fichiers de session locaux |
| Météo (facultatif) | Conditions de la session | Fichiers de session locaux |
| Réglages, progression du jeu, oiseau-thème choisi | Fonctionnement de l'app | Préférences locales |

Ces données ne quittent pas l'appareil, sauf dans les cas décrits ci-dessous.

## Ce qui peut quitter votre appareil

### Fonctions réseau facultatives (désactivées par défaut)

Chacune se règle dans **Paramètres > Confidentialité**. Rien n'est envoyé tant que vous n'avez pas activé
la fonction.

| Fonction | Service tiers | Ce qui est envoyé |
|---|---|---|
| Tuiles de carte | OpenStreetMap Foundation (`tile.openstreetmap.org`) ; Géoplateforme de l'IGN (`data.geopf.fr`) pour les fonds IGN | Coordonnées de la tuile affichée, adresse IP, identifiant de l'application |
| Nom de lieu | OpenStreetMap Nominatim | Latitude et longitude de la session, adresse IP |
| Météo | Open-Meteo (`api.open-meteo.com`) | Latitude, longitude et heure de fin de la session, adresse IP |
| Photos en grand format | iNaturalist (`api.inaturalist.org`) et ses serveurs d'images | Nom de l'espèce, adresse IP ; la photo est mise en cache sur l'appareil |

Ces services ont leur propre politique de confidentialité et peuvent traiter les données hors de
France. Nous ne recevons pas ces requêtes. Les noms de lieu, la météo et les photos reçus sont stockés
sur votre appareil.

### Ce que vous décidez d'envoyer ou de partager

- **Envoi à Faune-France / LPO** : l'application prépare une observation (espèce, date, lieu, extrait
  audio). C'est vous qui l'envoyez, en passant par la feuille de partage du système ou par
  l'application NaturaList. Ces données arrivent alors chez le destinataire que vous avez choisi, qui
  applique sa propre politique.
- **Exports** (CSV, GPX, JSON, rapport HTML, extraits audio) : créés sur votre appareil et partagés par
  la feuille de partage du système, uniquement quand vous le demandez. Ils peuvent contenir la position
  GPS. Le rapport HTML, ouvert dans un navigateur, peut charger des images d'espèces
  (birdnet.cornell.edu) et la bibliothèque de carte Leaflet (unpkg.com) : ces sites voient alors votre
  adresse IP.
- **Liens externes** (eBird, iNaturalist, Wikipédia, Faune-France, etc.) : ils s'ouvrent dans votre
  navigateur uniquement quand vous les touchez ; le site visité applique sa propre politique.

Aucune autre requête réseau n'est faite par l'application.

## Autorisations demandées

- **Microphone** : identifier les chants. Pendant une écoute, un service de premier plan avec
  notification permanente garde l'écoute active écran éteint.
- **Localisation** (précise et approximative, « pendant l'utilisation de l'app » ; pendant une écoute, la
  notification permanente maintient le suivi écran éteint) : marquer les détections et filtrer les
  espèces plausibles. L'application ne demande pas « Toujours autoriser ». Refusable ou révocable à tout
  moment dans les réglages du système.
- **Notifications** : indiquer l'écoute en cours et signaler une nouvelle espèce.
- **Internet** : uniquement pour les fonctions facultatives ci-dessus.

## Enfants

L'application s'adresse aux personnes de **13 ans et plus** et n'est pas destinée aux enfants de moins de
13 ans. Elle ne demande aucune donnée personnelle, ni compte, ni contact, et ne collecte rien à notre
niveau. Les fonctions réseau facultatives (désactivées par défaut) peuvent envoyer une adresse IP aux
services listés ci-dessus.

## Conservation et suppression

Tout est stocké sur votre appareil. Si la sauvegarde automatique d'Android est activée sur votre
téléphone, le système peut en copier une partie vers votre compte Google ; c'est un réglage du système,
que nous ne recevons pas. Vous pouvez supprimer une session depuis le carnet, ou tout effacer
dans **Paramètres > Zone dangereuse > Effacer toutes les données**. Désinstaller l'application supprime
aussi ses données locales. Comme nous ne recevons aucune donnée, nous n'avons rien à supprimer de notre côté.

## Vos droits

Ne détenant aucune donnée personnelle vous concernant, il n'y a rien à consulter, corriger ou
effacer chez nous. Pour les données traitées par les services tiers, adressez-vous à eux. Vous pouvez
introduire une réclamation auprès de la CNIL (cnil.fr).

## Données intégrées à l'application

Photos, descriptions, cartes de répartition (observations GBIF, limites Natural Earth) et modèles sont
**intégrés à l'application** : leur affichage ne fait aucune requête réseau.

## Crédits et licences

BirdyGo est un fork de BirdNET Live (Cornell Lab of Ornithology, TU Chemnitz), sous licence MIT. Les
modèles BirdNET+ sont sous licence Apache 2.0. BirdyGo n'est pas une application officielle BirdNET.

## Modifications

Toute modification de cette politique sera publiée à cette adresse avec une nouvelle date.

## Contact

[ADRESSE E-MAIL]
