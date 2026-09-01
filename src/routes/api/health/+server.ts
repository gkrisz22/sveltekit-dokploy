import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async () => {
	return json(
		{
			status: 'ok',
			timestamp: new Date().toISOString(),
			checks: {
				server: 'up',
				sveltekit: 'ok',
				nginx: 'proxied via :80 → :3000',
				traefik: 'tls via dokploy/traefik'
			}
		},
		{
			headers: {
				'cache-control': 'no-store'
			}
		}
	);
};
