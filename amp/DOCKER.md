# Running AMP with Docker

This brings up two containers: PostgreSQL 14 + PostGIS, and AMP on Tomcat 8.5.
It replaces the manual PostgreSQL / Tomcat / IntelliJ steps in the dev-setup
guide; you still need a database dump to get a usable site.

## Prerequisites

- Docker Engine 20.10+ with BuildKit, and the Compose v2 plugin.
- **`amp-boilerplate`, `amp-translate` and `amp-filter` must be present under
  `amp/TEMPLATE/ampTemplate/node_modules/`.** They are git submodules, so a
  downloaded zip of the repo leaves those three directories empty and the build
  fails in its first npm stage. In a git checkout:

  ```bash
  git submodule update --init --recursive
  ```

  The submodules are cloned over SSH, so you need a GitHub key that can read
  them. Some working copies instead vendor the same three packages one level up
  at `amp/TEMPLATE/ampTemplate/<name>/`; if the `node_modules/` copies are empty
  but those exist, copying them across is equivalent:

  ```bash
  cd amp/TEMPLATE/ampTemplate
  for d in amp-boilerplate amp-filter amp-translate; do cp -a "$d/." "node_modules/$d/"; done
  ```

- Around 10 GB of free disk and 6 GB of RAM available to Docker. The build
  compiles seven npm projects and then the Maven war, so the first run takes a
  while; later runs reuse the BuildKit npm/Maven caches.

## Quick start

```bash
cp .env.example .env        # optional, the defaults work as-is
docker compose up -d --build
docker compose logs -f amp
```

AMP is on <http://localhost:8080/> once the container reports healthy:

```bash
docker compose ps
```

The first boot runs the schema migrations and is slow — the healthcheck allows
ten minutes before it starts counting failures.

## Loading a database

A fresh stack has an empty schema and no site, so AMP will not serve anything
useful until you restore a country dump.

```bash
# The compose file publishes 5432, so the existing script works unchanged.
export AMP_DB_HOST=localhost AMP_DB_USER=amp AMP_DB_NAME=amp
export PGPASSWORD=amp122006
./scripts/restore.sh /path/to/amp_country.backup
```

Then point the site at your hostname, or AMP will not match the request:

```bash
docker compose exec db psql -U amp -d amp \
  -c "UPDATE dg_site_domain SET site_domain = 'localhost';"
docker compose restart amp
```

`scripts/restore.sh --docker` stops and starts a container named `amp`; this
stack names it `amp-develop-amp-1`, so either pass `AMP_CONTAINER` or restart
the service yourself as above.

## Configuration

Everything is set through `.env` (see `.env.example`). The ones that matter:

| Variable | Default | Notes |
| --- | --- | --- |
| `AMP_DB_NAME` / `AMP_DB_USER` / `AMP_DB_PASSWORD` | `amp` / `amp` / `amp122006` | Used for both the database container and AMP's datasources. |
| `AMP_SERVER_NAME` | `localhost` | Must equal `dg_site_domain` in the database. |
| `AMP_PUBLISHED_PORT` | `8080` | Host port for the webapp. |
| `AMP_DB_PUBLISHED_PORT` | `5432` | Host port for psql/pg_restore. |
| `AMP_MAX_HEAP` | `4g` | Tomcat max heap. Deployed servers use `8g`. |
| `AMP_SKIP_TESTS` | `true` | The Maven test suite needs a populated database, so it is skipped for local builds. |

The JDBC coordinates are compiled into `META-INF/context.xml` by the XSLT step
in `pom.xml`, which is why they are also build args. You do not normally need to
rebuild to change them: `amp/docker/entrypoint.sh` rewrites that file from the
`AMP_DB_*` environment on every start, so the same image can be pointed at a
different database.

### Pointing the image at an external database

```bash
docker run --rm -p 8080:8080 \
  -e AMP_DB_HOST=pg.internal -e AMP_DB_PORT=5432 \
  -e AMP_DB_NAME=amp_country_3 -e AMP_DB_USER=amp -e AMP_DB_PASSWORD=... \
  -e AMP_SERVER_NAME=amp.example.org \
  amp-develop-amp
```

## Persistence

| Volume | Holds |
| --- | --- |
| `db-data` | The PostgreSQL cluster. |
| `jackrabbit` | Jackrabbit's lucene index. The documents themselves live in the database via `jcrDS`. |
| `lucene` | AMP's own search indexes. |
| `heapdumps` | Where `-XX:+HeapDumpOnOutOfMemoryError` writes. |

`jackrabbit` and `lucene` are rebuilt from the database if you drop them; they
are kept only to make restarts quicker.

`docker compose down` keeps all of them. `docker compose down -v` deletes them,
including the database.

## Known issue: the runtime base image is on an EOL Debian

`amp/Dockerfile` runs on `tomcat:8.5.79-jdk8`, which is Debian 11 (bullseye).
Debian 11 is past end of life: `security.debian.org` still publishes a
`bullseye-security` index, but every package in its pool now returns 404. Any
`apt-get install` that resolves to a security version fails, which is what used
to break the final build stage.

The stage now deletes the `bullseye-security` entry and installs from
`deb.debian.org` only, and it no longer reinstalls `curl`, `gnupg` and
`ca-certificates` — those already ship in the base image, and asking for them
is what pulled in the unobtainable versions.

**This means the image gets no Debian security updates at build time.** That is
acceptable for local development but is not a good position for a deployed
image. The real fix is to move off Debian 11 — for example a Temurin/Ubuntu
`tomcat:8.5-jdk8` tag — which is a change to the runtime worth testing on its
own, not something to fold into a dockerization change.

Tomcat 8.5 itself is also end-of-life (March 2024).

## Notes

- `amp/context.xml` sets `<Resources cacheMaxSize="204800">` (200 MB). The
  exploded webapp is ~860 MB, 112 MB of that under `WEB-INF/classes`, and
  Tomcat's 10 MB default cannot hold the working set — it evicts constantly and
  logs `insufficient free space ... consider increasing the maximum size of the
  cache` for every resource it drops. The cache is on the heap, so keep it well
  under `AMP_MAX_HEAP`.

- `docker/postgres-init/` runs only on a **first** start against an empty
  `db-data` volume. Changing it after the fact does nothing until you recreate
  the volume.
- The build runs `mvn test` when `AMP_SKIP_TESTS=false`, which needs a populated
  database — that is how CI builds it, not how you build locally.
- If npm has to fetch a private `devgateway` dependency during the build, add
  `ssh: [default]` under `services.amp.build` in `docker-compose.yml` and run
  with an SSH agent loaded; the Dockerfile already declares the `type=ssh`
  mounts. The public dependencies build without it.
