# sveltekit-dokploy

Minimal **SvelteKit** (Svelte 5, `adapter-node`) demo that deploys via **GitHub Actions → GHCR → Dokploy Compose** with **nginx on `:80`** as reverse proxy. Dokploy/Traefik handles TLS on `:443` — the container only exposes `80`.

> **Flow:** `git push → GitHub Actions builds image → push `ghcr.io/<owner>/sveltekit-dokploy:latest+sha` → `POST /api/compose.deploy` → Dokploy `docker compose pull` ( `pull_policy: always` ) → Traefik `443 → 80 → nginx → node:3000`.
>
> No build on the Dokploy host — the image is built once in CI.

Live demo page shows health (`/api/health`), build info (`/api/info`), and hydration check.

## Stack

- **SvelteKit 2** + Svelte 5 (runes) + Vite 8
- **adapter-node** — Node server on `3000` (`build/index.js`)
- **nginx (alpine)** on `80` — reverse proxy, gzip, immutable-asset cache, security headers
- **Docker** multi-stage build (`node:22-alpine` + `nginx` + `tini`)
- **GHCR** (`ghcr.io`) — image registry, `latest` + `sha` tags, `cache-from: gha`
- **Dokploy Compose** + **Traefik** (Let’s Encrypt) for TLS
- **GitHub Actions** — typecheck → build image → push → `curl` to Dokploy API

## Architecture

```
Users (https) ──→ Traefik :443 (TLS) ──→ nginx :80 ──→ SvelteKit node :3000
                          Dokploy manages Traefik + certs
GitHub push ──→ Actions ──→ Build (Docker) ──→ Push ghcr.io/<repo>:latest & :<sha> (GHCR)
                         └─→ POST https://dokploy.example.com/api/compose.deploy
                             -H x-api-key: $DOKPLOY_TOKEN
                             -d {"composeId":"..."}
                             ──→ Dokploy: docker compose pull (always) && up -d
```

Why nginx on `:80`?

- Dokploy/Traefik terminates TLS; container only needs to expose `80` (`expose: ["80"]` in `docker-compose.yml`). No `ports:` in production — avoids host `80` collision with Traefik.
- nginx handles `proxy_set_header X-Forwarded-Proto`, gzip, and `/_app/immutable` caching without touching Node.
- No SSL inside the container — Traefik does it.

Why Compose + GHCR (vs. Dockerfile build on server)?

- **No load on Dokploy host** — `docker build` runs in GitHub’s runners with `gha` cache.
- **Immutable, auditable artifacts** — every deploy is a pinned image (`:sha` + `:latest`), easy rollback via Dokploy.
- **Faster deploys** — `pull` is faster than full `npm ci + vite build` on a small VPS.

## Quick start

```sh
npm install
npm run dev          # http://localhost:5173
npm run build        # → build/
npm run preview      # vite preview on :4173 (NOT the adapter-node server)
node build/index.js  # the actual production server, on :3000

# Docker — single image (as CI builds)
docker build -t sveltekit-dokploy .
docker run -p 8080:80 --rm sveltekit-dokploy
# http://localhost:8080  (nginx 80 → node 3000)
# http://localhost:8080/api/health
# http://localhost:8080/api/info

# Compose — local dev (builds locally, publishes 8080:80)
docker compose -f docker-compose.yml -f docker-compose.local.yml up --build
# http://localhost:8080  (override adds ports + build)

# Compose — production image (as Dokploy runs, no host port)
# First push an image to GHCR or build locally with the prod tag:
docker build -t ghcr.io/gkrisz22/sveltekit-dokploy:latest .
docker compose up
# (no host port — use docker-compose.local.yml for local)
```

> The image name is already set to `ghcr.io/gkrisz22/sveltekit-dokploy` in `docker-compose.yml`, `docker-compose.local.yml` and `docker-stack.yml`. If you fork or rename the repo, update all three — it must match `ghcr.io/<owner>/<repo>` in lowercase.

### Env

See `.env.example`. At runtime:

- `PORT=3000`, `HOST=0.0.0.0`, `NODE_ENV=production`
- `GIT_COMMIT_SHA`, `GIT_BRANCH`, `BUILD_TIME` are baked as `ARG` → `ENV` at `docker build` time (see the `ARG` block in `Dockerfile`) and shown via `/api/info`. Locally they default to `unknown`/`local`.

#### Running behind Traefik: the proxy headers matter

`docker-compose.yml` sets these, and you should keep them:

```yaml
PROTOCOL_HEADER: x-forwarded-proto
HOST_HEADER: x-forwarded-host
ADDRESS_HEADER: x-forwarded-for
XFF_DEPTH: 2
```

Without them, `adapter-node` builds `event.url` from the `Host` header over plain HTTP, because TLS was terminated upstream at Traefik. `url.origin` then comes out as `http://demo.example.com` while the browser sends `Origin: https://demo.example.com`, and SvelteKit's CSRF check rejects **every POST form action** with `Cross-site POST form submissions are forbidden`. There are no forms in this demo, so the bug is invisible here — it appears the moment you add one.

`XFF_DEPTH: 2` matches the two hops that prepend to `X-Forwarded-For` in this setup (Traefik, then nginx); raise it if you put another proxy in front. If you serve exactly one domain, `ORIGIN: https://demo.example.com` is a simpler alternative to all four.

## Deploy to Dokploy (Compose + GHCR)

### 1. Create Compose in Dokploy

1. Dokploy dashboard → **Project** → **Create Service** → **Compose**.
2. **Source Type:** `Git` → select provider/repo `gkrisz22/sveltekit-dokploy` → Branch `main` → **Compose File:** `./docker-compose.yml`.
   - Alternatively **Raw** and paste `docker-compose.yml` (not recommended — keep file in repo).
3. **Domains:** inside the Compose service → select service `app` → **Domains** → Add `demo.example.com` → **HTTPS / Let’s Encrypt** → Save.  
   Dokploy creates Traefik router `443 → app:80` automatically. Port in the UI should be `80`.
4. Env in Dokploy Compose UI (optional): `NODE_ENV=production` (already default in `docker-compose.yml`). Don't set `GIT_*` manually — CI bakes them.

> Ensure the `image:` in `docker-compose.yml` matches the image CI pushes (`ghcr.io/<owner>/<repo>:latest`). Update the file before first deploy.

### 2. Make GHCR package accessible

**Option A — Public (simplest for demo):**
- GitHub → repo → **Packages** → `sveltekit-dokploy` → **Package settings** → **Change visibility** → **Public**. Dokploy can `pull` unauthenticated.

**Option B — Private (recommended for prod):**
- Dokploy → **Settings** → **Registry** → **Add Registry** → `ghcr.io` → username `gkrisz22` + PAT (classic) with `read:packages`.  
  Or configure a GHCR PAT on the host’s `~/.docker/config.json` (Dokploy will use it for `compose pull`).
- Ensure the workflow’s `GITHUB_TOKEN` has `packages: write` (already set under `permissions:` in `deploy.yml`).

### 3. Create API token

Dokploy → **Profile / Settings** → **API Tokens** → **Create** → copy token (`dokploy_…`).

### 4. Get Compose ID

Open your Compose in Dokploy — URL is:
```
/dashboard/project/<projectId>/services/compose/<composeId>
```
Copy `<composeId>`.  
Via API: `GET /api/project.all` → `GET /api/compose.all` (filter by name).

### 5. Add GitHub secrets

Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**:

| Secret | Value | Example |
|--------|-------|---------|
| `DOKPLOY_URL` | Dokploy base URL (no trailing slash) | `https://dokploy.example.com` |
| `DOKPLOY_TOKEN` | API token from step 3 | `xxxx` |
| `DOKPLOY_COMPOSE_ID` | Compose ID from step 4 | `a1b2c3d4-…` |

No extra secrets needed for GHCR — `GITHUB_TOKEN` is auto-provided.

Optional variable for post-deploy health poll:
- `vars.APP_URL` = `https://demo.example.com` — the `healthcheck` job in `deploy.yml` is gated on `if: vars.APP_URL != ''` and is skipped until you set it.

### 6. Image name

Already set to `ghcr.io/gkrisz22/sveltekit-dokploy` in `docker-compose.yml`, `docker-compose.local.yml` and `docker-stack.yml`. Nothing to do unless you fork or rename the repo.

### 7. Push — CI builds, pushes, and deploys

```sh
git add .
git commit -m "feat: initial dokploy demo"
git push origin main
```

Workflow **`.github/workflows/deploy.yml`**:
- `check` ( `npm ci → svelte-check → vite build` )
- `build-and-push` ( `docker/build-push-action` → `ghcr.io/<repo>:latest` + `:<sha>` with `cache-from: gha`, `build-args: GIT_*` )
- `deploy` ( `curl -X POST "$DOKPLOY_URL/api/compose.deploy" -H "x-api-key: $DOKPLOY_TOKEN" -d '{"composeId":"..."}'` )

Check **Actions** tab → **Build & Deploy (Compose + GHCR → Dokploy)** → summary. Then Dokploy → **Compose** → **Deployments** for `pull` / `up` logs.

#### Dokploy API reference (Compose)

```
POST {DOKPLOY_URL}/api/compose.deploy
Headers:
  x-api-key: {DOKPLOY_TOKEN}
  Content-Type: application/json
Body:
  { "composeId": "{DOKPLOY_COMPOSE_ID}" }
# optional: "title", "description"
```

For a legacy **Application** service (Dockerfile build on server), the endpoint is `POST /api/application.deploy` with `{ "applicationId": "..." }` — not needed for this compose setup.

See `docs.dokploy.com/docs/api/compose` and `POST /api/compose.deploy`.

## Project structure

```
.
├── src/
│   ├── routes/
│   │   ├── +layout.svelte      # header/footer + global styles
│   │   ├── +page.svelte        # hero, health/info cards, arch diagram, deploy guide
│   │   └── api/
│   │       ├── health/+server.ts  # GET /api/health → {status, checks}
│   │       └── info/+server.ts    # GET /api/info   → {commit, branch, buildTime, ...}
│   ├── app.html
│   └── lib/assets/favicon.svg
├── static/robots.txt
├── svelte.config.js            # adapter-node
├── vite.config.ts
├── nginx.conf                  # 80 → 127.0.0.1:3000, gzip, cache for /_app/immutable
├── Dockerfile                  # builder → runner (node + nginx, tini, healthcheck)
├── docker-entrypoint.sh        # starts node + nginx, handles SIGTERM
├── docker-compose.yml          # PROD (Dokploy) — image: ghcr.io/...:latest, pull_policy: always, expose 80
├── docker-compose.local.yml    # LOCAL override — build + ports 8080:80
├── docker-stack.yml            # OPTIONAL raw Swarm stack — rolling zero-downtime updates
├── .github/workflows/
│   ├── deploy.yml              # check → build+push GHCR → curl compose.deploy
│   └── ci.yml                  # PR checks
└── .dockerignore / .env.example
```

## API

| Endpoint | Description |
|----------|-------------|
| `GET /api/health` | Liveness probe. Returns `{"status":"ok", "checks":{...}}`. Used by `HEALTHCHECK` and Dokploy. |
| `GET /api/info` | Build/runtime info: `commit`, `branch`, `buildTime`, `nodeVersion`, `hostname`, `uptime`. |

Both set `cache-control: no-store`.

## Troubleshooting

- **`svelte.config.js is ignored` warning** — ensure `vite.config.ts` uses `sveltekit()` with no args; all `kit`/`adapter` config lives in `svelte.config.js`.
- **`docker-compose.yml` image not found** — image name must be lowercase and match `ghcr.io/<owner>/<repo>`; check the `image:` line in `docker-compose.yml`. CI lowercases `github.repository` itself, so the pushed path is always `ghcr.io/<owner>/<repo>` in lowercase. For private packages, configure registry in Dokploy or make package public.
- **`pull access denied` on Dokploy host** — GHCR package is private and Dokploy has no credentials. See step 2 above; or `make package public`.
- **502 from nginx** — Node crashed or `PORT` mismatch. Check `docker compose logs app` (nginx's access/error logs are symlinked to the container's stdout/stderr, so they show up there too) and that `PORT=3000` matches the `upstream sveltekit` block in `nginx.conf`.
- **Dokploy returns 401/403** — token wrong or missing `x-api-key` header. Regenerate token, check `DOKPLOY_URL` has no trailing path, and `DOKPLOY_COMPOSE_ID` is a Compose ID (not Application ID).
- **Dokploy still builds instead of pulling** — ensure Compose service’s file is `docker-compose.yml` (prod, with `image:`), not a stale `Dockerfile` service. Compose deploy runs `compose pull`, not `build`.
- **TLS not working** — Domain must point to Dokploy server IP and Let’s Encrypt enabled in Dokploy domain settings. Container only listens on `80`.
- **Healthcheck fails in Dokploy** — Ensure healthcheck `curl -fsS http://127.0.0.1:80/api/health` ( `docker-compose.yml` ) and `HEALTHCHECK` in `Dockerfile` both succeed; Dokploy’s compose healthcheck is the container’s.

## Scripts

| Script | Description |
|--------|-------------|
| `npm run dev` | Vite dev server |
| `npm run build` | Production build (adapter-node) |
| `npm run preview` | Vite's preview server on `:4173`. To exercise the real adapter-node output, run `node build/index.js`. |
| `npm run check` | `svelte-check` type diagnostics |

## License

MIT — use as template for any SvelteKit → Dokploy Compose + GHCR project.
