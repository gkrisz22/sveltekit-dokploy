# syntax=docker/dockerfile:1.6

# ---------- Builder ----------
FROM node:22-alpine AS builder
WORKDIR /app

# Install deps first for better caching
COPY package.json package-lock.json* ./
RUN npm ci

# Copy source
COPY . .

# Build args for metadata (injected by CI)
ARG GIT_COMMIT_SHA=unknown
ARG GIT_BRANCH=unknown
ARG BUILD_TIME=unknown
ENV GIT_COMMIT_SHA=$GIT_COMMIT_SHA \
    GIT_BRANCH=$GIT_BRANCH \
    BUILD_TIME=$BUILD_TIME

RUN npm run build

# Prune dev deps (optional, keeps final image smaller if we copy node_modules)
# We don't need full node_modules in runtime — adapter-node's build is standalone except for `dependencies`
# For this demo there are no runtime deps, so we install prod only
RUN npm prune --omit=dev

# ---------- Runner ----------
FROM node:22-alpine AS runner
WORKDIR /app

# Install nginx and tini for proper init
RUN apk add --no-cache nginx tini curl \
    && mkdir -p /var/cache/nginx /var/log/nginx /var/run \
    && chown -R nginx:nginx /var/cache/nginx /var/log/nginx 2>/dev/null || true \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# Copy built app
COPY --from=builder /app/build ./build
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules

# Copy nginx config
COPY nginx.conf /etc/nginx/nginx.conf

# Copy entrypoint
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Env defaults — Dokploy will set PORT via UI if needed, but we default to 3000 for node
# nginx always on 80 (Dokploy expects 80)
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0

# Build metadata re-exposed as runtime env (overridden by CI if set at build time)
ARG GIT_COMMIT_SHA=unknown
ARG GIT_BRANCH=unknown
ARG BUILD_TIME=unknown
ENV GIT_COMMIT_SHA=$GIT_COMMIT_SHA \
    GIT_BRANCH=$GIT_BRANCH \
    BUILD_TIME=$BUILD_TIME

EXPOSE 80

# Healthcheck hits nginx -> node chain
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -fsS http://127.0.0.1:80/api/health | grep -q '"status":"ok"' || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/docker-entrypoint.sh"]
