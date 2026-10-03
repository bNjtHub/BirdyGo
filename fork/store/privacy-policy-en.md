# BirdyGo Privacy Policy

**Last updated:** [DATE]

> Draft adapted from the BirdNET Live policy (`docs/privacy.md`). Host it at a public web address before
> entering it in the Play Console. Fill the bracketed fields and re-read after any change to the network
> features. Remove this box before publishing.
>
> **Not verified (check before publishing):**
> - Android backup: the manifest does not set `allowBackup`, so automatic backup to the user's Google
>   account is on by default and may include sessions, locations and audio clips. The "Retention" section
>   mentions it; confirm or disable it.
> - Third-party retention periods (OSM, IGN, Open-Meteo, iNaturalist) are not restated (Open-Meteo's
>   90 days comes from the upstream policy).
> - The "Privacy policy" link on the About screen still points to the upstream website.

This policy applies to **BirdyGo** (the **app**, identifier `fr.justcodeit.birdygo`), an independent fork
of BirdNET Live. The app is published by [DEVELOPER NAME] (**we**).

| | |
|---|---|
| **App** | BirdyGo |
| **Developer** | [NAME / COMPANY] |
| **Privacy contact** | [EMAIL ADDRESS] |

## In short

- Song analysis runs **entirely on your device**. No recording is uploaded.
- No account, no ads, no analytics, no tracking, no automatic crash reports.
- We run no server that receives your data.
- Some optional features (maps, place names, weather, large photos) contact third-party services. They
  are **off by default** and you turn them on one by one.

## On-device processing

The microphone is used to identify birds with two locally run models: a BirdNET+ audio classifier and a
geomodel that estimates which species are likely at your location and time of year. No audio data is sent
to any server.

## Data stored on your device

| Data | Purpose | Storage |
|---|---|---|
| Audio clips of detections | Replay, quiz, export | Local files |
| Results (species, score, date, time, review status) | Notebook, statistics, progress | Local session files and local index |
| GPS location | Tagging detections, maps, geomodel | Local session files |
| Weather (optional) | Session conditions | Local session files |
| Settings, game progress, chosen companion bird | App operation | Local preferences |

This data does not leave the device except as described below.

## What can leave your device

### Optional network features (off by default)

Each is set in **Settings > Privacy**. Nothing is sent until you turn the feature on.

| Feature | Third-party service | What is sent |
|---|---|---|
| Map tiles | OpenStreetMap Foundation (`tile.openstreetmap.org`); French IGN Géoplateforme (`data.geopf.fr`) for IGN layers | Tile coordinates, IP address, app identifier |
| Place name | OpenStreetMap Nominatim | Session latitude and longitude, IP address |
| Weather | Open-Meteo (`api.open-meteo.com`) | Session latitude, longitude and end time, IP address |
| Large photos | iNaturalist (`api.inaturalist.org`) and its image servers | Species name, IP address; the photo is cached on the device |

These services have their own privacy policies and may process data outside your country. We do not
receive these requests. Place names, weather and photos received are stored on your device.

### What you decide to send or share

- **Sending to Faune-France / LPO**: the app prepares an observation (species, date, place, audio clip).
  You send it yourself, through the system share sheet or the NaturaList app. The data then reaches the
  recipient you chose, who applies its own policy.
- **Exports** (CSV, GPX, JSON, HTML report, audio clips): created on your device and shared through the
  system share sheet, only when you ask. They may contain GPS location. The HTML report, opened in a
  browser, may load species images (birdnet.cornell.edu) and the Leaflet map library (unpkg.com): those
  sites then see your IP address.
- **External links** (eBird, iNaturalist, Wikipedia, Faune-France, etc.): they open in your browser only
  when you tap them; the visited site applies its own policy.

The app makes no other network request.

## Permissions

- **Microphone**: identify songs. During a listening session a foreground service with a permanent
  notification keeps listening with the screen off.
- **Location** (precise and approximate, "while using the app"; during a session the permanent
  notification keeps tracking with the screen off): tag detections and filter plausible species. The app
  does not ask for "Allow all the time". You can refuse or revoke it at any time in system settings.
- **Notifications**: show the ongoing listening session and flag a new species.
- **Internet**: only for the optional features above.

## Children

The app is intended for people aged **13 and over** and is not directed to children under 13. It asks for
no personal data, no account, no contact, and collects nothing on our side. The optional network features
(off by default) may send an IP address to the services listed above.

## Retention and deletion

Everything is stored on your device. If Android's automatic backup is enabled on your phone, the system
may copy part of it to your Google account; that is a system setting and we do not receive it. You can
delete a session from the notebook, or erase everything in **Settings > Danger zone > Erase all data**.
Uninstalling the app also removes its local data. Since we receive no data, we hold nothing to delete.

## Your rights

As we hold no personal data about you, there is nothing for us to give access to, correct or erase. For
data processed by third-party services, contact them. You may lodge a complaint with your data protection
authority.

## Bundled data

Photos, descriptions, range maps (GBIF observations, Natural Earth boundaries) and models are **bundled in
the app**: displaying them makes no network request.

## Credits and licences

BirdyGo is a fork of BirdNET Live (Cornell Lab of Ornithology, Chemnitz University of Technology), under
the MIT licence. The BirdNET+ models are under the Apache 2.0 licence. BirdyGo is not an official BirdNET
app.

## Changes

Any change to this policy will be published at this address with a new date.

## Contact

[EMAIL ADDRESS]
