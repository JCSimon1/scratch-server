# Scratch Server (Self-Hosted)

This repository provides a self-hosted [Scratch](https://scratch.mit.edu) 3.0
editor, built from the Scratch Foundation's official
[scratch-editor](https://github.com/scratchfoundation/scratch-editor)
mono-repo, as a Docker container.

The image is **not** built on the target server. Instead, it's built
automatically via **GitHub Actions**. The finished, small image (just
`nginx` + static files) is pushed to the GitHub Container Registry
(`ghcr.io`). The server only needs to pull and start it — no compiling, no
high RAM requirement on the server.

---

## 1. Dockerfile

The `Dockerfile` uses a **multi-stage build**:

1. **Build stage (`node:24-bookworm`)**
   - clones the official `scratch-editor` mono-repo
   - installs all workspace dependencies (`npm install`)
   - builds **all** workspace packages in the correct order (`npm run build`),
     since `scratch-gui` depends on other packages in the repo
     (`scratch-storage`, `scratch-vm`, `scratch-render`,
     `scratch-svg-renderer`, `scratch-paint`, ...) that first need to be
     compiled from TypeScript themselves
   - `NODE_OPTIONS="--max-old-space-size=..."` raises the Node heap limit so
     the build doesn't fail with "JavaScript heap out of memory" on
     memory-constrained machines

2. **Runtime stage (`nginx:alpine`)**
   - copies only the finished static build
     (`packages/scratch-gui/build`) into `/usr/share/nginx/html`
   - result: a small, lean image with no Node.js/build tools included

The Dockerfile does **not** need to be modified locally — it's used
exclusively by GitHub Actions.

---

## 2. GitHub Actions workflow

File: [`.github/workflows/build.yml`](.github/workflows/build.yml)

**What the workflow does:**

- Runs automatically on every push to the `main` branch (or manually via
  "Run workflow" in the Actions tab, thanks to `workflow_dispatch`)
- Logs in to `ghcr.io` (GitHub Container Registry) using the
  automatically provided `GITHUB_TOKEN`
- Converts the repository owner name to lowercase, since Docker image
  names don't allow uppercase letters
- Builds the image according to the `Dockerfile` on a GitHub runner (which
  has enough RAM/CPU available — the build never runs locally or on the
  target server)
- Pushes the finished image to:
  ```
  ghcr.io/<github-owner-lowercase>/scratch-server:latest
  ```

**Checking progress/result:** the **"Actions"** tab in the repository. A
green checkmark means the image was built and published successfully.

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

- **`image`**: points to the image built by GitHub Actions in the GitHub
  Container Registry — **nothing is built locally**
  (no `build:` key needed)
- **`ports`**: the editor is then reachable via port `8601` on the host
- **`restart: unless-stopped`**: the container automatically restarts
  after a server reboot

---

## 4. Installing and starting the container

On the target server (e.g. an Ubuntu server with Docker & the Docker
Compose plugin installed):

1. Get the repository files onto the server, e.g. via `git clone`:
   ```bash
   git clone https://github.com/JCSimon1/scratch-server.git
   cd scratch-server
   ```

2. Start the container:
   ```bash
   docker compose up -d
   ```
   This simply pulls and starts the finished image — no build step, minimal
   RAM usage.

3. Open in your browser:
   ```
   http://<server-ip>:8601
   ```

### Updating to a newer version

Once a new commit has been pushed to `main` and the Actions workflow has
completed successfully, on the server:

```bash
docker compose pull
docker compose up -d
```

### Stopping / removing the container

```bash
docker compose down
```

---

## Notes

- This is the plain Scratch **editor** (offline/standalone mode). There
  are **no** user accounts and no online community features like on
  scratch.mit.edu. Projects are imported/exported locally as `.sb3` files.
- Upstream source: [scratchfoundation/scratch-editor](https://github.com/scratchfoundation/scratch-editor)

---

## License

The upstream project this image is built from,
[scratchfoundation/scratch-editor](https://github.com/scratchfoundation/scratch-editor),
is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**
(see [`LICENSE`](LICENSE) in this repository).

The AGPL is a network-copyleft license: anyone who runs the software (or a
modified version of it) as a publicly accessible network service must make
the corresponding source code available to users of that service — this
applies even if the code itself isn't distributed/downloaded.

This repository does not modify the upstream Scratch source code itself; it
only builds and packages it. The corresponding source code for the running
service is the unmodified upstream repository linked above. If you do make
changes to the Scratch source as part of your own deployment, you must make
your modified source available to users of your instance as well, per the
AGPL-3.0 terms.
