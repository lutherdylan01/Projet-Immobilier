# Logement CM : annonces de logements au Cameroun

Application mobile (Android) qui met en relation **bailleurs** et **locataires** au Cameroun.

- **Bailleur** : publie, modifie ou retire ses logements (photos, loyer, caution, avance, ville, quartier, position GPS, commodités comme le forage ou le compteur Eneo personnel).
- **Locataire** : cherche par ville, quartier, type et budget, consulte la fiche avec photos et carte.
- **Les deux** : discutent dans une messagerie intégrée (temps réel), liée à chaque logement.
- Boutons **WhatsApp**, **Appeler** et **Demander une visite** sur chaque annonce.
- Bouton **Signaler cette annonce** : après 3 signalements, l'annonce est masquée automatiquement en attendant votre vérification.

Technologies : [Flutter](https://flutter.dev) (l'application) + [Supabase](https://supabase.com) (comptes, base de données, photos, chat) + [OpenStreetMap](https://www.openstreetmap.org) (carte gratuite, sans carte bancaire).

> Ce guide suppose que vous partez de zéro. Suivez les étapes dans l'ordre. Comptez une demi-journée la première fois, surtout à cause des téléchargements.

---

## Sommaire

1. [Ce dont vous avez besoin](#1-ce-dont-vous-avez-besoin)
2. [Créer le projet Supabase](#2-créer-le-projet-supabase)
3. [Créer la base de données](#3-créer-la-base-de-données)
4. [Activer la connexion par SMS](#4-activer-la-connexion-par-sms)
5. [Récupérer les clés Supabase](#5-récupérer-les-clés-supabase)
6. [Installer Flutter et Android Studio](#6-installer-flutter-et-android-studio)
7. [Récupérer le code et le configurer](#7-récupérer-le-code-et-le-configurer)
8. [Lancer l'application sur votre téléphone](#8-lancer-lapplication-sur-votre-téléphone)
9. [Tester le parcours complet](#9-tester-le-parcours-complet)
10. [Créer un fichier APK à partager](#10-créer-un-fichier-apk-à-partager)
11. [Gérer les signalements](#11-gérer-les-signalements)
12. [Organisation du code](#12-organisation-du-code)
13. [Problèmes fréquents](#13-problèmes-fréquents)
14. [Et après ?](#14-et-après-)

---

## 1. Ce dont vous avez besoin

| Élément | Détail |
|---|---|
| Un ordinateur | Windows 10/11, macOS ou Linux, 8 Go de RAM conseillés, 15 Go d'espace disque libre |
| Un téléphone Android | N'importe lequel, Android 5 ou plus récent, et son câble USB |
| Une connexion Internet | Environ **5 Go** à télécharger au total (Flutter + Android Studio). Utilisez un Wi‑Fi si possible. |
| Une adresse e‑mail | Pour créer les comptes Supabase et GitHub |

Tout est **gratuit** pour démarrer. Seuls les SMS de connexion envoyés à de vrais utilisateurs sont payants (voir l'étape 4), mais vous pouvez tout tester sans payer.

---

## 2. Créer le projet Supabase

Supabase est le « serveur » de l'application : il garde les comptes, les annonces, les photos et les messages.

1. Allez sur <https://supabase.com> et cliquez sur **Start your project**.
2. Créez un compte (le plus simple : **Continue with GitHub**).
3. Cliquez sur **New project**.
4. Remplissez :
   - **Name** : `logement-cm`
   - **Database Password** : cliquez sur **Generate a password**, puis **copiez-le et gardez-le** dans un endroit sûr.
   - **Region** : choisissez **West EU (Paris)** ou **Central EU (Frankfurt)** (les plus proches du Cameroun).
   - **Plan** : Free.
5. Cliquez sur **Create new project** et patientez 1 à 2 minutes.

---

## 3. Créer la base de données

Le fichier [`supabase/migrations/0001_schema_initial.sql`](supabase/migrations/0001_schema_initial.sql) crée toutes les tables, les règles de sécurité, l'espace de stockage des photos et active le chat en temps réel.

1. Ouvrez le fichier `supabase/migrations/0001_schema_initial.sql` sur GitHub et cliquez sur l'icône **Copy raw file** (deux carrés superposés).
2. Dans Supabase, menu de gauche : **SQL Editor**.
3. Cliquez sur **New query** (ou le **+**).
4. Collez tout le contenu (Ctrl+V), puis cliquez sur **Run** (en bas à droite).
5. Vous devez voir **Success. No rows returned**.

Vérification : menu **Table Editor**. Vous devez voir 7 tables : `profiles`, `listings`, `listing_photos`, `conversations`, `messages`, `visit_requests`, `reports`. Dans le menu **Storage**, un espace `listing-photos` doit exister.

> Le script peut être relancé sans danger : il ne crée que ce qui manque.

### Ce que contient la base

| Table | Rôle |
|---|---|
| `profiles` | Un profil par utilisateur : téléphone, nom, rôle (bailleur ou locataire), WhatsApp |
| `listings` | Les logements : titre, type, loyer, caution, avance, ville, quartier, GPS, commodités, statut |
| `listing_photos` | Les photos de chaque logement (les fichiers sont dans Storage) |
| `conversations` | Une discussion = un locataire + un bailleur + un logement |
| `messages` | Les messages du chat |
| `visit_requests` | Les demandes de visite (en attente, acceptée, refusée, annulée) |
| `reports` | Les signalements d'annonces |

### La sécurité (RLS)

Chaque table est protégée par des règles **Row Level Security** : même si quelqu'un récupère vos clés publiques, il ne peut faire que ce que l'application autorise.

- Tout le monde voit les annonces **disponibles** ; un bailleur voit aussi toutes les siennes.
- Seul un utilisateur avec le rôle **bailleur** peut publier, et uniquement en son nom.
- Un bailleur ne peut modifier, retirer ou supprimer **que ses propres** annonces et photos.
- Les messages ne sont lisibles **que par les deux personnes** de la conversation.
- Un locataire peut annuler sa demande de visite ; seul le bailleur peut l'accepter ou la refuser.
- Le numéro de téléphone vérifié par SMS ne peut pas être modifié depuis l'application.
- Une personne ne peut signaler une annonce qu'une seule fois. À 3 signalements non traités, l'annonce passe en **suspendu** et le bailleur ne peut pas la réactiver lui-même.

Ces règles ont été testées automatiquement avant la publication du code.

---

## 4. Activer la connexion par SMS

Les utilisateurs se connectent avec leur numéro de téléphone et un code reçu par SMS.

1. Dans Supabase : **Authentication** > **Sign In / Providers** (ou **Providers** selon la version).
2. Cliquez sur **Phone** et activez **Enable Phone provider**.
3. Supabase demande un **fournisseur SMS**. Le plus simple est **Twilio** :
   - Créez un compte d'essai sur <https://www.twilio.com/try-twilio> (crédit offert à l'inscription).
   - Dans la console Twilio, copiez **Account SID**, **Auth Token**, et créez un **Messaging Service** pour obtenir son **Messaging Service SID**.
   - Collez ces trois valeurs dans Supabase.
4. **Pour tester sans envoyer de vrais SMS** : dans la même page, section **Test Phone Numbers and OTPs**, ajoutez par exemple :

   ```
   237690000001=123456, 237690000002=123456
   ```

   Ces numéros se connectent avec le code `123456`, sans SMS ni frais. Dans l'app, tapez `690000001` puis le code `123456`.
5. Cliquez sur **Save**.

> **Coût en production** : chaque SMS envoyé à un vrai numéro camerounais est facturé par Twilio (quelques dizaines de FCFA). Pensez à surveiller votre crédit. D'autres fournisseurs (Vonage, MessageBird, Textlocal) sont aussi proposés par Supabase.

---

## 5. Récupérer les clés Supabase

1. Dans Supabase : **Project Settings** (roue dentée en bas à gauche) > **API Keys**.
2. Copiez la **Publishable key** (elle commence par `sb_publishable_`).
   - Si votre projet affiche plutôt une clé **anon public** (onglet *Legacy API Keys*), elle fonctionne aussi.
3. Allez dans **Project Settings** > **Data API** (ou **API**) et copiez la **Project URL** (`https://xxxxx.supabase.co`).

> ⚠️ Ne copiez **jamais** la clé `secret` ou `service_role` dans l'application : elle contourne toute la sécurité.

Vous utiliserez ces deux valeurs à l'étape 7.

---

## 6. Installer Flutter et Android Studio

Les instructions ci-dessous sont pour **Windows**. Pour macOS ou Linux, suivez <https://docs.flutter.dev/get-started/install> en choisissant « Android ».

### 6.1 Installer Git

1. Téléchargez Git : <https://git-scm.com/download/win> et installez-le (gardez les options par défaut).

### 6.2 Installer Flutter

1. Allez sur <https://docs.flutter.dev/get-started/install/windows/mobile> et téléchargez le fichier zip **Flutter SDK** (version *stable*).
2. Créez le dossier `C:\dev` et décompressez le zip dedans. Vous obtenez `C:\dev\flutter`.
   (Évitez `C:\Program Files` et les chemins avec espaces ou accents.)
3. Ajoutez Flutter au **PATH** :
   - Touche Windows, tapez **variables d'environnement**, ouvrez **Modifier les variables d'environnement pour votre compte**.
   - Sélectionnez **Path** > **Modifier** > **Nouveau**, tapez `C:\dev\flutter\bin`, puis **OK** partout.
4. Ouvrez un **nouveau** terminal (touche Windows, tapez `cmd`) et tapez :

   ```
   flutter --version
   ```

   Si une version s'affiche, c'est bon.

### 6.3 Installer Android Studio

1. Téléchargez Android Studio : <https://developer.android.com/studio> et installez-le avec les options par défaut (*Standard*). Il télécharge l'**Android SDK** (plusieurs Go).
2. Dans Android Studio : **More Actions** > **SDK Manager** > onglet **SDK Tools**, cochez **Android SDK Command-line Tools**, puis **Apply**.
3. Dans le terminal, acceptez les licences Android (répondez `y` à chaque question) :

   ```
   flutter doctor --android-licenses
   ```

4. Vérifiez l'installation :

   ```
   flutter doctor
   ```

   Les lignes **Flutter** et **Android toolchain** doivent avoir une coche verte `[√]`. Les autres (Chrome, Visual Studio…) ne sont pas nécessaires.

### 6.4 (Conseillé) Installer VS Code

Un éditeur plus léger qu'Android Studio pour modifier le code : <https://code.visualstudio.com>, puis installez l'extension **Flutter** depuis l'onglet Extensions.

---

## 7. Récupérer le code et le configurer

1. Dans le terminal :

   ```
   cd C:\dev
   git clone https://github.com/lutherdylan01/Projet-Immobilier.git
   cd Projet-Immobilier
   ```

2. Copiez le fichier d'exemple de configuration :

   ```
   copy env.example.json env.json
   ```

   (sur macOS/Linux : `cp env.example.json env.json`)

3. Ouvrez `env.json` avec le Bloc-notes ou VS Code et remplacez les valeurs par celles de l'étape 5 :

   ```json
   {
     "SUPABASE_URL": "https://abcdefgh.supabase.co",
     "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_xxxxxxxxxxxx"
   }
   ```

   Le fichier `env.json` est ignoré par Git : vos clés ne seront pas publiées sur GitHub.

4. Téléchargez les bibliothèques utilisées par l'application :

   ```
   flutter pub get
   ```

---

## 8. Lancer l'application sur votre téléphone

### 8.1 Préparer le téléphone (une seule fois)

1. **Paramètres** > **À propos du téléphone** > touchez **7 fois** sur **Numéro de build** (ou *Version MIUI*, *Version du logiciel*… selon la marque). Un message « Vous êtes développeur » apparaît.
2. **Paramètres** > **Système** > **Options pour les développeurs** > activez **Débogage USB**.
3. Branchez le téléphone à l'ordinateur avec le câble USB et acceptez **Autoriser le débogage USB** sur le téléphone.
4. Vérifiez que l'ordinateur voit le téléphone :

   ```
   flutter devices
   ```

### 8.2 Lancer

```
flutter run --dart-define-from-file=env.json
```

La première fois, la compilation prend plusieurs minutes. L'application s'installe ensuite sur le téléphone et s'ouvre.

Pendant que l'app tourne, tapez `r` dans le terminal pour recharger après une modification du code, `q` pour quitter.

> Si vous oubliez `--dart-define-from-file=env.json`, l'app affiche « Configuration Supabase manquante ».

---

## 9. Tester le parcours complet

Utilisez les deux numéros de test de l'étape 4 (sur deux téléphones, ou en vous déconnectant depuis l'onglet **Profil**).

1. **Bailleur** : connectez-vous avec `690000001` / `123456`, entrez un nom, choisissez **Bailleur**.
   Onglet **Mes logements** > **Ajouter** : photos, loyer, caution, ville, quartier, position sur la carte, commodités > **Publier**.
2. **Locataire** : connectez-vous avec `690000002` / `123456`, choisissez **Locataire**.
   Onglet **Rechercher** : filtrez par ville ou budget, ouvrez l'annonce.
3. Sur la fiche : **Message** ouvre le chat, **Visite** envoie une demande de visite, **WhatsApp** et **Appeler** contactent le bailleur, le drapeau 🚩 en haut signale l'annonce.
4. Revenez sur le compte bailleur : onglet **Messages** pour répondre, onglet **Visites** pour accepter ou refuser.

Vous pouvez suivre tout ce qui se passe dans Supabase > **Table Editor**.

---

## 10. Créer un fichier APK à partager

Pour installer l'application sur d'autres téléphones sans câble (par WhatsApp, clé USB…) :

```
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
```

Les fichiers sont créés dans `build\app\outputs\flutter-apk\` :

| Fichier | Pour quels téléphones |
|---|---|
| `app-arm64-v8a-release.apk` | La plupart des téléphones récents (≈ 2019 et après) |
| `app-armeabi-v7a-release.apk` | Les téléphones d'entrée de gamme ou plus anciens |

`--split-per-abi` produit des fichiers plus légers (environ 2 fois plus petits), ce qui économise les données de ceux qui les téléchargent. Sur le téléphone, il faudra autoriser l'installation d'« applications de sources inconnues ».

> Pour publier sur le Google Play Store, il faudra plus tard signer l'application avec votre propre clé : voir <https://docs.flutter.dev/deployment/android>.

---

## 11. Gérer les signalements

Vous êtes l'administrateur : vous gérez les signalements directement depuis Supabase.

- **Voir les signalements** : **Table Editor** > `reports`.
- **Annonces suspendues automatiquement** (3 signalements) : **Table Editor** > `listings`, filtrez `status = suspendu`.
- **Réactiver une annonce** après vérification : **SQL Editor**, remplacez l'identifiant puis **Run** :

  ```sql
  update reports  set handled = true        where listing_id = 'ID-DE-L-ANNONCE';
  update listings set status  = 'disponible' where id        = 'ID-DE-L-ANNONCE';
  ```

- **Supprimer une arnaque** : `delete from listings where id = 'ID-DE-L-ANNONCE';`

---

## 12. Organisation du code

```
Projet-Immobilier/
├── README.md                     ← ce guide
├── env.example.json              ← modèle de configuration (copier en env.json)
├── pubspec.yaml                  ← liste des bibliothèques Flutter
├── supabase/
│   └── migrations/
│       └── 0001_schema_initial.sql   ← tables, sécurité RLS, stockage, temps réel
├── android/                      ← projet Android (permissions, icône, nom de l'app)
├── test/                         ← tests automatiques (flutter test)
└── lib/                          ← le code de l'application
    ├── main.dart                 ← point de départ : connexion à Supabase
    ├── app.dart                  ← thème, langue française, aiguillage selon la connexion
    ├── config.dart               ← réglages (bucket photos, nb de photos, pagination)
    ├── models/                   ← les « objets » : Profil, Logement, Message, Visite
    ├── services/                 ← tout ce qui parle à Supabase (1 fichier par sujet)
    ├── screens/
    │   ├── auth/                 ← numéro de téléphone, code SMS, choix du rôle
    │   ├── search/               ← recherche du locataire
    │   ├── listing/              ← fiche logement, formulaire, carte, mes logements
    │   ├── chat/                 ← liste des conversations et discussion
    │   ├── visits/               ← demandes de visite
    │   ├── profile/              ← profil et déconnexion
    │   └── home_screen.dart      ← barre de navigation du bas
    ├── widgets/                  ← éléments réutilisés (carte d'annonce, carte, signalement…)
    └── utils/                    ← formats (FCFA, dates, téléphone), villes, commodités
```

**Ajouter une commodité** : ajoutez une ligne dans `lib/utils/amenities.dart` (aucun changement de base de données nécessaire).
**Ajouter une ville** : ajoutez-la dans la liste `cameroonCities` de `lib/utils/format.dart`.

### Choix pour le bas débit et les petits téléphones

- **Photos compressées sur le téléphone** avant l'envoi (1280 px max, qualité 70 %) : environ 150 Ko au lieu de 3 à 5 Mo.
- **Une seule photo** chargée par annonce dans la liste de résultats ; toutes les photos seulement sur la fiche.
- **Pagination** : 20 annonces à la fois, la suite se charge en faisant défiler.
- **Cache des images** sur le téléphone : une photo déjà vue n'est pas retéléchargée.
- **Images décodées en petite taille** pour économiser la mémoire.
- **APK séparés par processeur** (`--split-per-abi`) pour un téléchargement plus léger.
- **Carte OpenStreetMap** : gratuite, sans clé. Si l'application devient très utilisée, il faudra passer à un fournisseur de tuiles dédié (MapTiler, Stadia Maps… avec offre gratuite), comme le demande la [politique d'usage d'OpenStreetMap](https://operations.osmfoundation.org/policies/tiles/). Il suffira de changer `osmTileUrl` dans `lib/widgets/listing_map.dart`.

### Vérifier le code

```
flutter analyze   # cherche les erreurs dans le code
flutter test      # lance les tests automatiques
```

---

## 13. Problèmes fréquents

| Problème | Solution |
|---|---|
| `flutter` n'est pas reconnu | Le PATH n'est pas bon (étape 6.2). Fermez et rouvrez le terminal. |
| `flutter devices` ne voit pas le téléphone | Changez de câble (certains ne font que charger), réactivez le débogage USB, acceptez l'autorisation sur le téléphone. |
| « Configuration Supabase manquante » | Lancez avec `--dart-define-from-file=env.json` et vérifiez que `env.json` existe. |
| Pas de SMS reçu | Vérifiez le fournisseur SMS (étape 4) et votre crédit Twilio, ou utilisez un numéro de test. |
| « Code incorrect ou expiré » | Le code expire au bout de quelques minutes : touchez **Renvoyer le code**. |
| « Action non autorisée » en publiant | Le compte n'a pas le rôle **Bailleur** : changez-le dans l'onglet **Profil**. |
| Les photos ne s'envoient pas | Vérifiez que l'étape 3 a bien créé l'espace `listing-photos` dans **Storage**. |
| Le chat ne se met pas à jour tout seul | Supabase > **Database** > **Publications** > `supabase_realtime` : la table `messages` doit être cochée. |
| La carte reste grise | Vérifiez la connexion Internet du téléphone. |

---

## 14. Et après ?

Hors du périmètre de cette première version, à envisager ensuite :

- Notation des bailleurs par étoiles (1 à 5), sans commentaire écrit.
- Notifications push pour les nouveaux messages et visites.
- Favoris et alertes « nouveau logement dans mon quartier ».
- Recherche sur la carte (voir les annonces autour de soi).
- Petit tableau de bord d'administration pour la modération.
