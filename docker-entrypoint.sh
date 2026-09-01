#!/bin/sh
set -e

echo ">> Starting sveltekit-dokploy"
echo "   PORT=${PORT:-3000} HOST=${HOST:-0.0.0.0} NODE_ENV=${NODE_ENV:-production}"
echo "   GIT_COMMIT_SHA=${GIT_COMMIT_SHA:-unknown} GIT_BRANCH=${GIT_BRANCH:-unknown} BUILD_TIME=${BUILD_TIME:-unknown}"

# Ensure nginx cache dir exists
mkdir -p /var/cache/nginx
chown -R nginx:nginx /var/cache/nginx 2>/dev/null || true

# Test nginx config
nginx -t

# Start SvelteKit (adapter-node) in background
# build/index.js is the entry from @sveltejs/adapter-node
node build/index.js &
NODE_PID=$!
echo ">> SvelteKit PID $NODE_PID"

# Start nginx in background so we can supervise both and trap signals
nginx -g 'daemon off;' &
NGINX_PID=$!
echo ">> nginx PID $NGINX_PID"

SHUTTING_DOWN=0

# Forward SIGTERM/SIGINT to both children, then reap them
_term() {
  SHUTTING_DOWN=1
  echo ">> Caught SIGTERM/SIGINT, shutting down..."
  kill -TERM "$NODE_PID" 2>/dev/null || true
  nginx -s quit 2>/dev/null || true
  wait "$NODE_PID" 2>/dev/null || true
  wait "$NGINX_PID" 2>/dev/null || true
  exit 0
}
trap _term TERM INT

# Supervise: poll both PIDs. `wait -n` is not POSIX (BusyBox ash support varies),
# and masking its failure would make the container tear itself down on startup.
# A 1s poll is cheap and portable across ash/dash/bash.
EXIT_CODE=0
while true; do
  if ! kill -0 "$NODE_PID" 2>/dev/null; then
    wait "$NODE_PID"; EXIT_CODE=$?
    echo ">> SvelteKit exited (code $EXIT_CODE)"
    break
  fi
  if ! kill -0 "$NGINX_PID" 2>/dev/null; then
    wait "$NGINX_PID"; EXIT_CODE=$?
    echo ">> nginx exited (code $EXIT_CODE)"
    break
  fi
  sleep 1
done

if [ "$SHUTTING_DOWN" = "1" ]; then
  exit 0
fi

# One process died on its own -> take the whole container down so the
# orchestrator (compose restart / Swarm restart_policy) recreates it.
# Never exit 0 here: Swarm's `condition: on-failure` would not restart.
echo ">> Peer process gone, stopping the other..."
kill -TERM "$NODE_PID" 2>/dev/null || true
nginx -s quit 2>/dev/null || true
sleep 2
kill -9 "$NODE_PID" 2>/dev/null || true
kill -9 "$NGINX_PID" 2>/dev/null || true

if [ "$EXIT_CODE" -eq 0 ]; then
  EXIT_CODE=1
fi
echo ">> Exiting with code $EXIT_CODE"
exit $EXIT_CODE
