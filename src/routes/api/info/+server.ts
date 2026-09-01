import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';
import os from 'node:os';

export const GET: RequestHandler = async () => {
	// These are injected at build time via Docker ARG / env
	// Fallbacks keep local dev working
	const commit = process.env.GIT_COMMIT_SHA ?? process.env.GITHUB_SHA ?? 'unknown';
	const branch = process.env.GIT_BRANCH ?? process.env.GITHUB_REF_NAME ?? 'unknown';
	const buildTime = process.env.BUILD_TIME ?? new Date().toISOString();

	return json(
		{
			status: 'ok',
			timestamp: new Date().toISOString(),
			commit,
			branch,
			buildTime,
			nodeVersion: process.version,
			hostname: os.hostname(),
			uptime: process.uptime(),
			env: process.env.NODE_ENV ?? 'production'
		},
		{
			headers: { 'cache-control': 'no-store' }
		}
	);
};
