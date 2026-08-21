# --- Stage 1: Build ---
FROM node:24-bookworm AS builder

# Native Build-Abhängigkeiten für node-canvas (wird von scratch-paint /
# scratch-svg-renderer benötigt)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    python3 \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Node-Heap-Limit erhöhen, damit der TypeScript/Webpack-Build bei wenig
# RAM nicht mit "JavaScript heap out of memory" abbricht
ENV NODE_OPTIONS="--max-old-space-size=2560"

# Aktuelles Scratch-Editor-Mono-Repo klonen (offizielles Repo der Scratch Foundation)
RUN git clone --depth 1 https://github.com/scratchfoundation/scratch-editor.git .

# Workspace-weite Abhängigkeiten installieren (npm workspaces)
RUN npm install

# Alle Workspace-Pakete in der richtigen Reihenfolge bauen (scratch-storage,
# scratch-vm, scratch-render, ... werden von scratch-gui benötigt und müssen
# vorher kompiliert sein). Landet am Ende in packages/scratch-gui/build.
RUN npm run build

# --- Stage 2: Runtime ---
FROM nginx:alpine

COPY --from=builder /src/packages/scratch-gui/build /usr/share/nginx/html

EXPOSE 80
