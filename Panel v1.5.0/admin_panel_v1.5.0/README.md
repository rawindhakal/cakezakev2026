# CakeZake - Hyperlocal Quick Commerce & eCommerce Platform with Multi-Branch & Multi-Country

CakeZake is a Laravel 12 + Vue 3 admin panel and REST API powering a multi-country,
multi-language online store that supports both **ecommerce** (item-wise fulfilment)
and **quick commerce** (single-branch, order-wise) sales channels.

- **Author:** CakeZake · support@cakezake.com · https://cakezake.com
- **Support:** support@cakezake.com

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Backend | PHP (Laravel 12), Laravel Passport (OAuth) |
| Admin frontend | Vue 3 (Options API) + Bootstrap-Vue-Next, built with Vite |
| Database | MySQL 8 |
| Realtime | Laravel Reverb / Pusher (chat, notifications) |
| Storage | Local disk (`storage/app/public` via `storage:link`) |

---

## Requirements

- **PHP ≥ 8.3** with extensions: `zip`, `curl`,
  `mbstring`, `openssl`, `pdo_mysql`, `gd`, `fileinfo`
- **Composer** 2.x
- **Node.js** ≥ 18 + npm (only to build the frontend)
- **MySQL** ≥ 8.0

---

## Installation

### Option A — Web installer (recommended)
1. Upload the code and point the web root at `public/`.
2. Copy `.env.example` to `.env` (leave `APP_KEY=` empty — it is generated on first run).
3. Visit the site; the installer wizard checks requirements, collects DB + admin
   credentials, runs migrations/seeders, installs Passport keys, and links storage.

### Option B — Manual (CLI)
```bash
composer install --no-dev --optimize-autoloader
cp .env.example .env
php artisan key:generate
php artisan migrate --seed
php artisan passport:install
php artisan storage:link
npm install && npm run build
```

---

## Queues & Scheduled Tasks

Two separate pieces of setup, and the panel prints both with the real paths filled in:
**Settings → Cron Jobs**.

### 1. Scheduler — one cron entry

```
* * * * * cd /path/to/project && php artisan schedule:run >> /dev/null 2>&1
```

Runs the timed tasks: cart reminders, maintenance windows, scheduled home-layout and
popup publishing, spin-wheel campaigns, courier tracking sync. The page shows a
heartbeat, so a cron that is not firing is visible instead of silent.

### 2. Queue worker — a daemon, not a cron entry

Background jobs (order emails, push notifications, referral and cashback credits, bulk
product imports) are run by a worker that stays in memory. Use Supervisor, or in aaPanel:
**App Store → Supervisor Manager**.

```ini
[program:cakezake-queue]
process_name=%(program_name)s_%(process_num)02d
command=php /path/to/project/artisan queue:work --sleep=3 --tries=3 --max-time=3600 --max-jobs=1000
directory=/path/to/project
user=www-data
numprocs=1
autostart=true
autorestart=true
stopasgroup=true
killasgroup=true
stopwaitsecs=3660
redirect_stderr=true
stdout_logfile=/path/to/project/storage/logs/queue-worker.log
```

Do **not** put `queue:work` in cron. Draining the queue on the minute boots the whole
framework every minute to usually find nothing, leaves a job waiting up to a minute, and
`--max-time` cannot cut a running job short — so a slow one overlaps the next run and
doubles the database load. A daemon boots once, picks a job up in seconds, and Supervisor
restarts it if it dies.

Run `php artisan queue:restart` after every deployment, so the worker reloads the new
code. The System Updater and the plugin installer already signal this; a manual deploy
needs it by hand.

**Shared hosting with no daemon:** set `QUEUE_SCHEDULER_FALLBACK=true` and the minute
scheduler drains the queue instead. That is the old behaviour, kept only for hosts that
cannot run a worker — the Cron Jobs page says so while it is on.

---

## Configuration (.env highlights)

| Key | Purpose |
|-----|---------|
| `APP_KEY` | Encryption key — auto-generated on first boot if empty |
| `DB_*` | Database connection |
| `DEMO_MODE` | `1` = read-only demo (write routes blocked for non-super-admin) |
| `REVERB_*` / `PUSHER_*` | Realtime broadcast credentials (chat / notifications) |
| `WEBSITE_URL` | Public storefront URL |
| `QUEUE_CONNECTION` | `database` in production; `sync` runs jobs inside the request |
| `QUEUE_SCHEDULER_FALLBACK` | `true` only where no queue worker daemon can run |

> Read config via `config('app.demo_mode')` (not `env()`) so it stays correct when
> config is cached.

---

## Building the Frontend

```bash
npm run dev     # local development (HMR)
npm run build   # production assets into public/build
```

---

## Updating

Updates are applied from the admin panel: **Settings → System Updater**, by uploading
an official update package.

- **Package name must be** `cakezake-update-<x.y.z>.zip` — the version is read from the
  file name and must be strictly newer than the installed version.
- The panel takes the app offline, overlays the package onto the app root, runs
  `php artisan migrate --force`, clears caches, signals the queue worker to restart, and
  updates `version.txt`.
- Ship **all** reference-data changes (permissions, templates, settings) as **idempotent
  migrations** — install seeders run on fresh installs only, never on update.

Build a package with:
```bash
bash scripts/make-update-package.sh   # bump version.txt + npm run build first
```

---

## Deployment Notes

- Never commit/deploy a stale `bootstrap/cache/config.php`; run `php artisan optimize:clear`
  (or delete it) after uploading code so the server reads its own `.env`.
- Keep `storage/` and `bootstrap/cache/` writable by the web user
  (`chown -R www:www storage bootstrap/cache`); a permission error there breaks
  push-notification token caching and file writes.
- Composer resolves for PHP 8.3 (`config.platform.php` in `composer.json`); run
  `composer install` on a PHP 8.3 host so `platform_check` matches.

---

## License

Proprietary — © CakeZake. Redistribution requires a valid purchase/license.
