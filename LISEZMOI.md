# Tir Parcours

Appli de saisie et de suivi des tirs de parcours : 3D et Nature (FFTA), Safari (UFOLEP).
Elle fonctionne sans réseau sur le parcours, puis envoie les données dans Supabase dès que le réseau revient.

## Contenu du dossier

| Fichier | Rôle |
|---|---|
| `index.html` | L'appli |
| `config.js` | Adresse et clé publique Supabase (à remplir) |
| `sw.js` | Fonctionnement hors ligne |
| `manifest.webmanifest`, `icon-192.png`, `icon-512.png` | Installation sur la tablette (icône, nom) |
| `supabase.sql` | Création de la table `parcours_items` (une seule fois) |

## Mise en route (une seule fois)

### 1. Supabase : créer la table
1. Ouvrir le projet Supabase du Carnet de l'entraîneur.
2. Menu **SQL Editor** → **New query**.
3. Coller tout le contenu de `supabase.sql` → **Run**.
4. Vérifier dans **Table Editor** qu'une table `parcours_items` est apparue.
   Les tables du Carnet ne sont pas modifiées.

### 2. Remplir `config.js`
1. Dans Supabase : **Project Settings** → **API** (ou **Data API**).
2. Copier le **Project URL** dans `supabaseUrl`.
3. Copier la clé **anon public** dans `supabaseAnonKey`.
   Ne jamais mettre la clé `service_role`.

### 3. GitHub : créer le dépôt
1. Sur github.com : **New repository** → nom `tir-parcours` → **Public** → **Create repository**.
2. Cliquer sur **uploading an existing file**.
3. Glisser les 8 fichiers du dossier (dont `config.js` rempli) → **Commit changes**.
4. **Settings** → **Pages** → Source : **Deploy from a branch** → Branch : `main` / `(root)` → **Save**.
5. Après 1 à 2 minutes, l'appli est en ligne : `https://cedr-cmyk.github.io/tir-parcours/`

### 4. Sur la tablette
1. Ouvrir l'adresse dans Chrome.
2. Menu ⋮ → **Installer l'application** (ou **Ajouter à l'écran d'accueil**).
3. Dans l'appli : **Réglages** → **Se connecter**, avec le même compte que le Carnet.

### 5. Récupérer les données de la version Claude
1. Dans la version Claude : **Réglages** → **Copier toutes les données**.
2. Dans la version GitHub : **Réglages** → coller dans « Importer » → **Importer**.

## Mettre à jour l'appli plus tard
1. Remplacer `index.html` (et les autres fichiers modifiés) dans le dépôt GitHub.
2. Dans `sw.js`, changer le numéro de `CACHE` (ex. `tir-parcours-v0.3` → `tir-parcours-v0.4`).
3. Sur la tablette, ouvrir l'appli avec du réseau : la nouvelle version est prise au 2e lancement.

## Bon à savoir
- Ouvrir l'appli une première fois **avec du réseau** sur chaque tablette, pour qu'elle se mette en mémoire.
- Le badge en haut à droite indique l'état : « en attente » = données gardées sur la tablette, envoyées au retour du réseau.
- Pour l'instant, chaque compte ne voit que ses propres données (pas encore d'espace archer).
