<script lang="ts">
	import favicon from '$lib/assets/favicon.svg';

	let { children } = $props();
</script>

<svelte:head>
	<link rel="icon" href={favicon} />
	<title>SvelteKit • Dokploy Demo</title>
</svelte:head>

<div class="app">
	<header class="header">
		<div class="header-inner">
			<a href="/" class="brand">
				<span class="brand-icon">▲</span>
				<span class="brand-text">sveltekit-dokploy</span>
				<span class="brand-badge">demo</span>
			</a>
			<nav class="nav">
				<a href="https://svelte.dev/docs/kit" target="_blank" rel="noreferrer">SvelteKit Docs</a>
				<a href="https://dokploy.com/docs" target="_blank" rel="noreferrer">Dokploy Docs</a>
				<a href="https://github.com" target="_blank" rel="noreferrer">GitHub</a>
			</nav>
		</div>
	</header>

	<main class="main">
		{@render children()}
	</main>

	<footer class="footer">
		<div class="footer-inner">
			<span>Built with SvelteKit + adapter-node • Served via nginx:80 • TLS by Traefik (Dokploy)</span>
			<span class="footer-dot">•</span>
			<a href="https://github.com">View on GitHub</a>
		</div>
	</footer>
</div>

<style>
	:global(*) {
		box-sizing: border-box;
	}
	:global(html, body) {
		margin: 0;
		padding: 0;
		font-family:
			'Inter', ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial,
			sans-serif;
		background: #0a0a0f;
		color: #e6e6eb;
		line-height: 1.5;
		-webkit-font-smoothing: antialiased;
	}
	:global(a) {
		color: inherit;
	}
	.app {
		min-height: 100dvh;
		display: flex;
		flex-direction: column;
		background:
			radial-gradient(1200px 600px at 20% -10%, rgba(255, 62, 0, 0.15), transparent 60%),
			radial-gradient(900px 500px at 90% 0%, rgba(99, 102, 241, 0.18), transparent 60%),
			radial-gradient(800px 400px at 50% 120%, rgba(16, 185, 129, 0.08), transparent 60%),
			#0a0a0f;
	}
	.header {
		position: sticky;
		top: 0;
		z-index: 10;
		backdrop-filter: blur(12px);
		background: rgba(10, 10, 15, 0.7);
		border-bottom: 1px solid rgba(255, 255, 255, 0.06);
	}
	.header-inner {
		max-width: 1100px;
		margin: 0 auto;
		padding: 14px 20px;
		display: flex;
		align-items: center;
		justify-content: space-between;
		gap: 16px;
	}
	.brand {
		display: flex;
		align-items: center;
		gap: 10px;
		text-decoration: none;
		font-weight: 600;
		letter-spacing: -0.02em;
	}
	.brand-icon {
		width: 28px;
		height: 28px;
		display: grid;
		place-items: center;
		background: #ff3e00;
		color: white;
		border-radius: 7px;
		font-size: 14px;
		font-weight: 800;
		transform: rotate(0deg);
	}
	.brand-text {
		font-size: 15px;
	}
	.brand-badge {
		font-size: 11px;
		font-weight: 700;
		letter-spacing: 0.08em;
		text-transform: uppercase;
		background: rgba(255, 255, 255, 0.08);
		border: 1px solid rgba(255, 255, 255, 0.1);
		padding: 2px 7px;
		border-radius: 999px;
		color: #a1a1b5;
	}
	.nav {
		display: flex;
		gap: 18px;
		font-size: 13px;
		color: #a1a1b5;
	}
	.nav a {
		text-decoration: none;
		transition: color 0.15s;
	}
	.nav a:hover {
		color: #fff;
	}
	.main {
		flex: 1;
		max-width: 1100px;
		width: 100%;
		margin: 0 auto;
		padding: 32px 20px 48px;
	}
	.footer {
		border-top: 1px solid rgba(255, 255, 255, 0.06);
		background: rgba(255, 255, 255, 0.02);
	}
	.footer-inner {
		max-width: 1100px;
		margin: 0 auto;
		padding: 16px 20px;
		display: flex;
		gap: 10px;
		flex-wrap: wrap;
		align-items: center;
		justify-content: center;
		font-size: 12px;
		color: #8b8ba3;
	}
	.footer-inner a {
		color: #a1a1b5;
		text-decoration: underline;
		text-underline-offset: 3px;
	}
	.footer-dot {
		opacity: 0.5;
	}
	@media (max-width: 640px) {
		.nav {
			display: none;
		}
		.footer-inner {
			text-align: center;
		}
	}
</style>
