#!/bin/sh
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /usr/src/app/tmp/pids/server.pid

# Update crontab file using whenever command
bundle exec whenever --update-crontab

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
