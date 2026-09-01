<script lang="ts">
	import { onMount } from 'svelte';

	type Info = {
		status: string;
		timestamp: string;
		commit?: string;
		branch?: string;
		buildTime?: string;
		nodeVersion: string;
		hostname: string;
		uptime: number;
		env: string;
	};

	let info: Info | null = $state(null);
	let health: { status: string; checks: Record<string, string> } | null = $state(null);
	let healthError: string | null = $state(null);
	let infoError: string | null = $state(null);
	let loadingHealth = $state(false);
	let loadingInfo = $state(false);
	let counter = $state(0);

	async function fetchHealth() {
		loadingHealth = true;
		healthError = null;
		try {
			const res = await fetch('/api/health');
			if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
			health = await res.json();
		} catch (e) {
			healthError = e instanceof Error ? e.message : String(e);
		} finally {
			loadingHealth = false;
		}
	}

	async function fetchInfo() {
		loadingInfo = true;
		infoError = null;
		try {
			const res = await fetch('/api/info');
			if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
			info = await res.json();
		} catch (e) {
			infoError = e instanceof Error ? e.message : String(e);
		} finally {
			loadingInfo = false;
		}
	}

	onMount(() => {
		fetchHealth();
		fetchInfo();
	});
</script>

<svelte:head>
	<meta
		name="description"
		content="SvelteKit demo deployed via GitHub Actions → GHCR → Dokploy Compose (nginx on :80, Traefik SSL)"
	/>
</svelte:head>

<!-- HERO -->
<section class="hero">
	<div class="hero-badge">
		<span class="pulse"></span>
		GitHub Actions → GHCR → Dokploy Compose • Live
	</div>
	<h1 class="hero-title">
		SvelteKit on <span class="accent">Dokploy</span>
		<br /><span class="muted">Compose + GHCR demo</span>
	</h1>
	<p class="hero-desc">
		Production SvelteKit (adapter-node) behind <code>nginx:80</code>. CI builds the image and pushes
		to <code>ghcr.io</code> (<code>:latest</code> + <code>:sha</code>), then triggers Dokploy
		Compose <code>pull</code> via API. Dokploy/Traefik terminates TLS — no build on the host.
	</p>
	<div class="hero-cta">
		<button class="btn primary" onclick={fetchHealth} disabled={loadingHealth}>
			{loadingHealth ? 'Checking…' : '↻ Check /api/health'}
		</button>
		<button class="btn ghost" onclick={fetchInfo} disabled={loadingInfo}>
			{loadingInfo ? 'Loading…' : 'View build info'}
		</button>
		<a class="btn ghost" href="#deploy">How to deploy →</a>
	</div>
	<div class="hero-meta">
		<span>PORT <strong>3000</strong> (node) ← <strong>80</strong> (nginx) ← <strong>443</strong> (Traefik)</span>
		<span class="sep">•</span>
		<span>Healthcheck <code>/api/health</code></span>
	</div>
</section>

<!-- STATUS GRID -->
<section class="grid">
	<div class="card">
		<div class="card-head">
			<h3>● Health</h3>
			<span class="tag" class:ok={health?.status === 'ok'} class:bad={healthError}>
				{healthError ? 'error' : health?.status ?? '—'}
			</span>
		</div>
		{#if healthError}
			<p class="error">{healthError}</p>
		{:else if health}
			<dl class="dl">
				{#each Object.entries(health.checks) as [k, v]}
					<div><dt>{k}</dt><dd>{v}</dd></div>
				{/each}
			</dl>
		{:else}
			<p class="muted-sm">Fetching /api/health…</p>
		{/if}
		<code class="code">GET /api/health</code>
	</div>

	<div class="card">
		<div class="card-head">
			<h3>◍ Build Info</h3>
			<span class="tag">{info?.env ?? '—'}</span>
		</div>
		{#if infoError}
			<p class="error">{infoError}</p>
		{:else if info}
			<dl class="dl">
				<div><dt>status</dt><dd>{info.status}</dd></div>
				<div><dt>commit</dt><dd class="mono">{info.commit?.slice(0, 7) ?? 'unknown'}</dd></div>
				<div><dt>branch</dt><dd>{info.branch ?? '—'}</dd></div>
				<div><dt>node</dt><dd>{info.nodeVersion}</dd></div>
				<div><dt>hostname</dt><dd class="mono">{info.hostname}</dd></div>
				<div><dt>uptime</dt><dd>{Math.floor(info.uptime)}s</dd></div>
				<div><dt>built</dt><dd>{info.buildTime ?? info.timestamp}</dd></div>
			</dl>
		{:else}
			<p class="muted-sm">Fetching /api/info…</p>
		{/if}
		<code class="code">GET /api/info</code>
	</div>

	<div class="card interactive">
		<div class="card-head">
			<h3>↻ Hydration Check</h3>
			<span class="tag ok">client JS {counter % 2 === 0 ? '●' : '○'}</span>
		</div>
		<p class="muted-sm">
			If this counter works, SvelteKit hydration + client JS is OK behind nginx/Traefik.
		</p>
		<div class="counter">
			<button class="btn small" onclick={() => counter--}>−</button>
			<span class="counter-val">{counter}</span>
			<button class="btn small primary" onclick={() => counter++}>+</button>
		</div>
		<code class="code">Svelte 5 runes • $state</code>
	</div>
</section>

<!-- ARCH -->
<section class="arch">
	<h2>Architecture</h2>
	<div class="arch-diagram">
		<div class="arch-row">
			<span class="arch-node gh">GitHub<br /><small>push → Actions</small></span>
			<span class="arch-arrow">—→</span>
			<span class="arch-node api">GHCR<br /><small>build & push :latest :sha</small></span>
			<span class="arch-arrow">—→</span>
			<span class="arch-node api">Dokploy API<br /><small>POST /api/compose.deploy</small></span>
			<span class="arch-arrow">—→</span>
			<span class="arch-node docker">Docker pull<br /><small>ghcr.io → compose up</small></span>
		</div>
		<div class="arch-row second">
			<span class="arch-node users">Users<br /><small>https://example.com</small></span>
			<span class="arch-arrow">—→</span>
			<span class="arch-node traefik">Traefik<br /><small>:443 → :80 (TLS)</small></span>
			<span class="arch-arrow">—→</span>
			<span class="arch-node nginx">nginx<br /><small>:80 → :3000</small></span>
			<span class="arch-arrow">—→</span>
			<span class="arch-node node">SvelteKit<br /><small>node :3000</small></span>
		</div>
	</div>
	<p class="muted-sm" style="margin-top: 12px">
		<strong>Why nginx on :80 + compose?</strong> Production <code>docker-compose.yml</code> uses
		<code>image: ghcr.io/...:latest</code> with <code>pull_policy: always</code> — Dokploy only pulls,
		never builds. <code>expose: 80</code> only (no host <code>ports:</code>) avoids collision with
		Traefik’s <code>:80</code>. Traefik routes <code>443 → 80</code>.
	</p>
</section>

<!-- DEPLOY STEPS -->
<section id="deploy" class="deploy">
	<h2>Deploy via GitHub Actions → GHCR → Dokploy Compose</h2>
	<div class="steps">
		<ol>
			<li>
				<strong>Create Compose in Dokploy</strong> — Project → Create Service → <code>Compose</code> → Source
				<code>Git</code> → repo <code>gkrisz22/sveltekit-dokploy</code>, Branch <code>main</code>, Compose
				File <code>./docker-compose.yml</code>.
			</li>
			<li>
				<strong>Set image in compose</strong> — In repo edit <code>docker-compose.yml</code>:
				<code>image: ghcr.io/gkrisz22/sveltekit-dokploy:latest</code> (lowercase, matches
				<code>github.repository</code>). CI pushes <code>:latest</code> + <code>:sha</code>.
			</li>
			<li>
				<strong>Add domain</strong> — Dokploy → Compose → service <code>app</code> → Domains → Add
				<code>demo.example.com</code> + enable <code>Let's Encrypt</code> → Traefik <code>443 → 80</code>.
				No <code>ports:</code> in prod compose ( <code>expose: 80</code> + <code>pull_policy: always</code> ).
			</li>
			<li>
				<strong>GHCR access</strong> — Public: Repo → Packages → Visibility → Public. Private: Dokploy →
				Settings → Registry → add <code>ghcr.io</code> PAT with <code>read:packages</code>.
			</li>
			<li>
				<strong>Generate API token</strong> — Dokploy → Profile → API Tokens → Create (copy token).
			</li>
			<li>
				<strong>Grab Compose ID</strong> — Open Compose in Dokploy; URL is
				<code>/dashboard/project/&lt;projectId&gt;/services/compose/&lt;composeId&gt;</code>
				or <code>GET /api/compose.all</code>.
			</li>
			<li>
				<strong>Add GitHub Secrets</strong> — Repo → Settings → Secrets:
				<code>DOKPLOY_URL</code> (e.g. <code>https://dokploy.yourdomain.com</code>), <code
					>DOKPLOY_TOKEN</code
				>, <code>DOKPLOY_COMPOSE_ID</code>.
			</li>
			<li>
				<strong>Push to main</strong> — Workflow builds, pushes to GHCR, then
				calls <code>POST /api/compose.deploy</code> with <code>x-api-key</code> → Dokploy
				<code>compose pull</code>.
			</li>
		</ol>
		<div class="code-block">
			<div class="code-head">.github/workflows/deploy.yml — build → push → deploy</div>
			<pre><code
					>{`# 1) Build & push (GHCR)
- uses: docker/build-push-action@v6
  with:
    push: true
    tags: ghcr.io/<owner>/<repo>:latest,ghcr.io/<owner>/<repo>:\${{ github.sha }}
    build-args: GIT_COMMIT_SHA=\${{ github.sha }}

# 2) Trigger Dokploy Compose pull
- run: |
    curl -X POST "$DOKPLOY_URL/api/compose.deploy" \\
      -H "x-api-key: $DOKPLOY_TOKEN" \\
      -H "Content-Type: application/json" \\
      -d "{\\"composeId\\":\\"$DOKPLOY_COMPOSE_ID\\"}" \\
      --fail --show-error`}</code
				></pre>
		</div>
	</div>
</section>

<!-- LOCAL DEV -->
<section class="local">
	<h3>Local dev</h3>
	<div class="code-block small">
		<pre><code
				>{`npm install
npm run dev          # http://localhost:5173
npm run build        # vite build (adapter-node)
npm run preview      # vite preview :4173
node build/index.js  # real prod server :3000

docker build -t sveltekit-dokploy .
docker run -p 8080:80 --rm sveltekit-dokploy
# http://localhost:8080 -> nginx 80 -> node 3000
curl http://localhost:8080/api/health

# Compose local (adds build + ports)
docker compose -f docker-compose.yml -f docker-compose.local.yml up --build
# http://localhost:8080

# Compose prod (as Dokploy — pulls ghcr image, no host port)
docker compose up
# configure Domains in Dokploy; local use compose.local.yml`}</code
			></pre>
	</div>
</section>

<style>
	.hero {
		padding: 36px 0 8px;
	}
	.hero-badge {
		display: inline-flex;
		align-items: center;
		gap: 8px;
		font-size: 12px;
		font-weight: 600;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: #a1a1b5;
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.08);
		padding: 6px 12px;
		border-radius: 999px;
	}
	.pulse {
		width: 8px;
		height: 8px;
		background: #10b981;
		border-radius: 50%;
		box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
		animation: pulse 2s infinite;
	}
	@keyframes pulse {
		0% {
			box-shadow: 0 0 0 0 rgba(16, 185, 129, 0.7);
		}
		70% {
			box-shadow: 0 0 0 8px rgba(16, 185, 129, 0);
		}
		100% {
			box-shadow: 0 0 0 0 rgba(16, 185, 129, 0);
		}
	}
	.hero-title {
		margin: 18px 0 12px;
		font-size: clamp(32px, 6vw, 52px);
		line-height: 0.95;
		letter-spacing: -0.04em;
		font-weight: 800;
	}
	.hero-title .accent {
		background: linear-gradient(135deg, #ff3e00, #ff6b35);
		-webkit-background-clip: text;
		-webkit-text-fill-color: transparent;
		background-clip: text;
	}
	.hero-title .muted {
		font-weight: 300;
		color: #8b8ba3;
		font-size: 0.62em;
		letter-spacing: -0.03em;
	}
	.hero-desc {
		max-width: 680px;
		color: #a1a1b5;
		font-size: 15px;
		line-height: 1.6;
		margin: 0;
	}
	.hero-desc code {
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.08);
		padding: 1px 6px;
		border-radius: 5px;
		font-size: 13px;
		color: #e6e6eb;
	}
	.hero-cta {
		display: flex;
		gap: 10px;
		flex-wrap: wrap;
		margin-top: 22px;
	}
	.btn {
		appearance: none;
		border: 1px solid rgba(255, 255, 255, 0.12);
		background: rgba(255, 255, 255, 0.06);
		color: #e6e6eb;
		padding: 9px 16px;
		border-radius: 10px;
		font-size: 13px;
		font-weight: 600;
		cursor: pointer;
		text-decoration: none;
		display: inline-flex;
		align-items: center;
		justify-content: center;
		transition:
			background 0.15s,
			border-color 0.15s,
			transform 0.08s;
	}
	.btn:hover {
		background: rgba(255, 255, 255, 0.1);
		border-color: rgba(255, 255, 255, 0.18);
	}
	.btn:active {
		transform: scale(0.98);
	}
	.btn.primary {
		background: #ff3e00;
		border-color: #ff3e00;
		color: white;
	}
	.btn.primary:hover {
		background: #e63800;
	}
	.btn.ghost {
		background: transparent;
	}
	.btn.small {
		padding: 6px 12px;
		font-size: 14px;
		min-width: 36px;
	}
	.hero-meta {
		margin-top: 14px;
		display: flex;
		gap: 10px;
		flex-wrap: wrap;
		font-size: 12px;
		color: #6b6b84;
	}
	.hero-meta strong {
		color: #a1a1b5;
	}
	.hero-meta code {
		background: rgba(255, 255, 255, 0.06);
		padding: 1px 5px;
		border-radius: 4px;
	}
	.sep {
		opacity: 0.4;
	}

	.grid {
		display: grid;
		grid-template-columns: repeat(3, 1fr);
		gap: 16px;
		margin-top: 36px;
	}
	.card {
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.07);
		border-radius: 16px;
		padding: 18px 16px 14px;
		backdrop-filter: blur(8px);
	}
	.card-head {
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 8px;
		margin-bottom: 10px;
	}
	.card-head h3 {
		margin: 0;
		font-size: 13px;
		letter-spacing: -0.01em;
	}
	.tag {
		font-size: 11px;
		font-weight: 700;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		padding: 3px 8px;
		border-radius: 999px;
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.08);
		color: #a1a1b5;
	}
	.tag.ok {
		background: rgba(16, 185, 129, 0.15);
		border-color: rgba(16, 185, 129, 0.25);
		color: #6ee7b7;
	}
	.tag.bad {
		background: rgba(239, 68, 68, 0.15);
		border-color: rgba(239, 68, 68, 0.25);
		color: #fca5a5;
	}
	.dl {
		margin: 0;
		display: flex;
		flex-direction: column;
		gap: 6px;
	}
	.dl div {
		display: flex;
		justify-content: space-between;
		gap: 12px;
		font-size: 13px;
		border-bottom: 1px dashed rgba(255, 255, 255, 0.06);
		padding-bottom: 6px;
	}
	.dl div:last-child {
		border-bottom: none;
	}
	.dl dt {
		color: #8b8ba3;
		font-size: 12px;
	}
	.dl dd {
		margin: 0;
		font-weight: 600;
		color: #e6e6eb;
		text-align: right;
		word-break: break-all;
	}
	.dl dd.mono {
		font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
		font-size: 12px;
		font-weight: 500;
	}
	.muted-sm {
		color: #8b8ba3;
		font-size: 13px;
		line-height: 1.5;
		margin: 0 0 8px;
	}
	.muted-sm code {
		background: rgba(255, 255, 255, 0.06);
		padding: 1px 5px;
		border-radius: 4px;
		font-size: 12px;
	}
	.error {
		color: #fca5a5;
		background: rgba(239, 68, 68, 0.08);
		border: 1px solid rgba(239, 68, 68, 0.15);
		padding: 8px 10px;
		border-radius: 8px;
		font-size: 12px;
		word-break: break-all;
	}
	.code {
		display: inline-block;
		margin-top: 10px;
		font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
		font-size: 11px;
		color: #8b8ba3;
		background: rgba(255, 255, 255, 0.04);
		border: 1px solid rgba(255, 255, 255, 0.06);
		padding: 3px 8px;
		border-radius: 999px;
	}
	.card.interactive {
		display: flex;
		flex-direction: column;
	}
	.counter {
		display: flex;
		align-items: center;
		gap: 12px;
		margin-top: 12px;
	}
	.counter-val {
		min-width: 48px;
		height: 36px;
		display: grid;
		place-items: center;
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 10px;
		font-weight: 700;
		font-size: 16px;
	}

	.arch {
		margin-top: 36px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 16px;
		padding: 20px 18px;
	}
	.arch h2 {
		margin: 0 0 14px;
		font-size: 14px;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: #a1a1b5;
	}
	.arch-diagram {
		display: flex;
		flex-direction: column;
		gap: 12px;
	}
	.arch-row {
		display: flex;
		align-items: center;
		gap: 8px;
		flex-wrap: wrap;
	}
	.arch-row.second {
		opacity: 0.95;
	}
	.arch-node {
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.08);
		padding: 8px 12px;
		border-radius: 10px;
		font-size: 12px;
		font-weight: 600;
		text-align: center;
		line-height: 1.2;
		min-width: 110px;
	}
	.arch-node small {
		font-weight: 400;
		color: #8b8ba3;
		font-size: 10px;
	}
	.arch-node.gh {
		background: rgba(99, 102, 241, 0.15);
		border-color: rgba(99, 102, 241, 0.25);
	}
	.arch-node.api {
		background: rgba(255, 62, 0, 0.12);
		border-color: rgba(255, 62, 0, 0.22);
	}
	.arch-node.docker {
		background: rgba(14, 165, 233, 0.12);
		border-color: rgba(14, 165, 233, 0.22);
	}
	.arch-node.traefik {
		background: rgba(16, 185, 129, 0.12);
		border-color: rgba(16, 185, 129, 0.22);
	}
	.arch-node.nginx {
		background: rgba(34, 197, 94, 0.12);
		border-color: rgba(34, 197, 94, 0.22);
	}
	.arch-node.node {
		background: rgba(255, 62, 0, 0.12);
		border-color: rgba(255, 62, 0, 0.22);
	}
	.arch-arrow {
		color: #6b6b84;
		font-weight: 700;
		font-size: 12px;
	}

	.deploy {
		margin-top: 36px;
	}
	.deploy h2 {
		font-size: 18px;
		letter-spacing: -0.02em;
		margin: 0 0 12px;
	}
	.steps {
		display: grid;
		gap: 18px;
	}
	.steps ol {
		margin: 0;
		padding-left: 18px;
		display: flex;
		flex-direction: column;
		gap: 10px;
		color: #a1a1b5;
		font-size: 13px;
		line-height: 1.6;
	}
	.steps ol li::marker {
		color: #ff3e00;
		font-weight: 700;
	}
	.steps ol strong {
		color: #e6e6eb;
	}
	.steps ol code {
		background: rgba(255, 255, 255, 0.06);
		border: 1px solid rgba(255, 255, 255, 0.06);
		padding: 1px 5px;
		border-radius: 4px;
		font-size: 12px;
		color: #e6e6eb;
	}
	.code-block {
		background: #0f0f14;
		border: 1px solid rgba(255, 255, 255, 0.08);
		border-radius: 12px;
		overflow: hidden;
	}
	.code-block.small pre {
		padding: 14px 16px;
	}
	.code-head {
		font-size: 11px;
		font-weight: 600;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: #8b8ba3;
		padding: 10px 16px;
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
		background: rgba(255, 255, 255, 0.02);
	}
	.code-block pre {
		margin: 0;
		padding: 16px;
		overflow-x: auto;
		font-size: 12px;
		line-height: 1.6;
		color: #cbd5e1;
	}
	.code-block code {
		font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
	}

	.local {
		margin-top: 28px;
		background: rgba(255, 255, 255, 0.03);
		border: 1px solid rgba(255, 255, 255, 0.06);
		border-radius: 16px;
		padding: 18px;
	}
	.local h3 {
		margin: 0 0 10px;
		font-size: 13px;
		letter-spacing: 0.06em;
		text-transform: uppercase;
		color: #a1a1b5;
	}

	@media (max-width: 900px) {
		.grid {
			grid-template-columns: 1fr;
		}
	}
	@media (max-width: 640px) {
		.arch-row {
			gap: 6px;
		}
		.arch-node {
			min-width: 90px;
			padding: 6px 8px;
		}
	}
</style>
