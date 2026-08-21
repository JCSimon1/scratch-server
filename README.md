# Scratch Server (Self-Hosted)

Dieses Repository stellt einen selbstgehosteten [Scratch](https://scratch.mit.edu)-Editor
(Scratch 3.0, aus dem offiziellen [scratch-editor](https://github.com/scratchfoundation/scratch-editor)-Repo
der Scratch Foundation) als Docker-Container bereit.

Der Build läuft **nicht** auf dem Zielserver, sondern automatisiert über **GitHub Actions**.
Das fertige, kleine Image (nur `nginx` + statische Dateien) wird zur GitHub Container Registry
(`ghcr.io`) gepusht. Der Server muss das Image nur noch pullen und starten.

---

## 1. Dockerfile

Das `Dockerfile` verwendet einen **Multi-Stage-Build**:

1. **Build-Stage (`node:24-bookworm`)**
   - klont das offizielle `scratch-editor`-Mono-Repo
   - installiert alle Workspace-Abhängigkeiten (`npm install`)
   - baut **alle** Workspace-Pakete in der richtigen Reihenfolge (`npm run build`),
     da `scratch-gui` von anderen Paketen im Repo abhängt (`scratch-storage`,
     `scratch-vm`, `scratch-render`, `scratch-svg-renderer`, `scratch-paint`, ...),
     die selbst erst aus TypeScript kompiliert werden müssen
   - `NODE_OPTIONS="--max-old-space-size=..."` erhöht das Node-Heap-Limit, damit
     der Build bei begrenztem RAM nicht mit "JavaScript heap out of memory" abbricht

2. **Runtime-Stage (`nginx:alpine`)**
   - kopiert ausschließlich den fertigen statischen Build
     (`packages/scratch-gui/build`) in `/usr/share/nginx/html`
   - Ergebnis: ein sehr kleines, schlankes Image ohne Node.js/Build-Tools

Das Dockerfile muss lokal **nicht angepasst** werden – es wird ausschließlich
von GitHub Actions verwendet.

---

## 2. GitHub Actions Workflow

Datei: [`.github/workflows/build.yml`](.github/workflows/build.yml)

**Was der Workflow macht:**

- Läuft automatisch bei jedem Push auf den `main`-Branch (oder manuell über
  "Run workflow" im Actions-Tab, dank `workflow_dispatch`)
- Loggt sich mit dem automatisch bereitgestellten `GITHUB_TOKEN` bei
  `ghcr.io` (GitHub Container Registry) ein
- Wandelt den Repository-Besitzer-Namen in Kleinbuchstaben um, da
  Docker-Image-Namen keine Großbuchstaben erlauben
- Baut das Image gemäß `Dockerfile` auf einem GitHub-Runner (dort steht
  ausreichend RAM/CPU zur Verfügung – der Build läuft nicht lokal oder auf
  dem Zielserver)
- Pusht das fertige Image nach:
  ```
  ghcr.io/<github-owner-lowercase>/scratch-server:latest
  ```

**Fortschritt/Ergebnis prüfen:** Tab **"Actions"** im Repository. Ein grüner
Haken bedeutet, das Image wurde erfolgreich gebaut und veröffentlicht.

**Package-Sichtbarkeit:** Neu erstellte Packages sind standardmäßig
**privat**. Damit der Server das Image ohne Login pullen kann, entweder:

- Package → *Package settings* → *Danger Zone* → *Change visibility* → **Public**, oder
- auf dem Server einloggen:
  ```bash
  docker login ghcr.io -u <dein-github-username>
  ```
  (als Passwort einen Personal Access Token mit `read:packages`-Berechtigung verwenden)

---

## 3. docker-compose.yml

```yaml
services:
  scratch:
    image: ghcr.io/jcsimon1/scratch-server:latest
    container_name: scratch
    ports:
      - "8601:80"
    restart: unless-stopped
```

- **`image`**: verweist auf das von GitHub Actions gebaute Image in der
  GitHub Container Registry – es wird **nichts lokal gebaut**
  (kein `build:` Schlüssel mehr nötig)
- **`ports`**: Editor ist danach über Port `8601` des Hosts erreichbar
- **`restart: unless-stopped`**: Container startet automatisch nach einem
  Server-Neustart neu

---

## 4. Installation und Start des Containers

Auf dem Zielserver (z. B. Ubuntu-Server mit installiertem Docker & Docker
Compose Plugin):

1. Repository-Dateien auf den Server bringen, z. B. per `git clone`:
   ```bash
   git clone https://github.com/JCSimon1/scratch-server.git
   cd scratch-server
   ```

2. Falls das GitHub-Package **privat** ist, einmalig einloggen:
   ```bash
   docker login ghcr.io -u <dein-github-username>
   ```

3. Container starten:
   ```bash
   docker compose up -d
   ```
   Es wird lediglich das fertige Image gepullt und gestartet – kein Build,
   kaum RAM-Bedarf.

4. Im Browser aufrufen:
   ```
   http://<server-ip>:8601
   ```

### Aktualisieren auf eine neuere Version

Sobald ein neuer Commit auf `main` gepusht wurde und der Actions-Workflow
erfolgreich durchgelaufen ist, auf dem Server:

```bash
docker compose pull
docker compose up -d
```

### Container stoppen / entfernen

```bash
docker compose down
```

---

## Hinweise

- Dies ist der reine Scratch-**Editor** (Offline-/Standalone-Modus). Es gibt
  **keine** Benutzerkonten, keine Online-Community-Funktionen wie auf
  scratch.mit.edu. Projekte werden lokal als `.sb3`-Datei ex-/importiert.
- Basis-Repo: [scratchfoundation/scratch-editor](https://github.com/scratchfoundation/scratch-editor)
