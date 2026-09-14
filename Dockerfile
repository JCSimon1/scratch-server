# Build
FROM node:24-bookworm AS builder

# Native build dependencies for node-canvas (required by scratch-paint /
# scratch-svg-renderer)
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

# Increase the Node heap limit so the TypeScript/Webpack build doesn't
# crash with "JavaScript heap out of memory" when RAM is low.
ENV NODE_OPTIONS="--max-old-space-size=2560"

# Clone the current Scratch Editor mono-repo (official Scratch Foundation repo)
RUN git clone --depth 1 https://github.com/scratchfoundation/scratch-editor.git .

# Install workspace-wide dependencies (npm workspaces)
RUN npm install

# Build all workspace packages in the correct order (scratch-storage,
# scratch-vm, scratch-render, etc. are required by scratch-gui and must
# be compiled beforehand). Ends up in packages/scratch-gui/build.
RUN npm run build

# Runtime 
FROM nginx:alpine

COPY --from=builder /src/packages/scratch-gui/build /usr/share/nginx/html

EXPOSE 80
