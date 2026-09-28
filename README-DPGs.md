# Digital Public Goods — local Docker setup

Projects cloned from the [DPG Registry](https://www.digitalpublicgoods.net/registry), all verified DPGs.

| Folder | DPG | Domain | URL | Default login |
|---|---|---|---|---|
| `mifos-fineract/` + `mifos-web-app/` | Mifos X (Apache Fineract) | Fintech – core banking | UI: http://localhost:4200 · API: https://localhost:8443/fineract-provider | `mifos` / `password` |
| `openmrs/` | OpenMRS 3 | Healthcare – medical records | http://localhost/openmrs/spa | `admin` / `Admin123` |
| `dhis2/` | DHIS2 | Healthcare – health information / analytics | http://localhost:8085 | `admin` / `district` |
| `ckan/` | CKAN | Open data portal | http://localhost:81 (HTTPS also on :8444) | `ckan_admin` / `test1234` |
| `amp/` | AMP (Aid Management Platform) | Aid / development finance | http://localhost:8080 | `admin@amp.org` / `admin123` |

AMP uses ports 8080/5432, so the stacks above avoid those ports. It is a fresh clone of
`devgateway/amp` (`develop`) plus the local Docker layer (`docker-compose.yml`, `docker/`, `DOCKER.md`,
`amp/Dockerfile`, `amp/docker/{entrypoint,setenv}.sh`). Its database is an empty bootstrap
(no activities/donors/locations) — see `amp/DOCKER.md` to restore a real country dump instead.

```sh
cd amp && docker compose up -d --build     # first build is long (npm + Maven)
bash docker/bootstrap/bootstrap.sh          # only on a fresh (empty) database
docker compose restart amp                  # AMP then needs ~1–2 min to boot
```

Bootstrap fixes made here (the old copy in `Downloads\amp-develop` does not have them):
`20-legacy-relations.sql` adds `amp_activity_version.prj_implementation_unit` (without it startup failed
and every page returned 404), `54-site-wiring.sql` registers a `default` instance for every AMP module
(without them `/aim/*` pages returned 404 after login), and `60-admin-user.sql` sets `email_bouncing`
(a NULL there made login fail with HTTP 500). For the white page: `54-site-wiring.sql` also seeds the
home content page and the default user groups, `53-numeric-settings.sql` adds two report year settings
(`/rest/amp/settings` returned 500, so the JS header never drew), `60-admin-user.sql` re-runs the base
menu patches, and `amp/TEMPLATE/ampTemplate/site-config.xml` gives the `default` layout a body (it pointed
at a non-existent `body.jsp`, so `/` died mid-page). The empty bootstrap still lacks most reference data
(Feature Manager tree, later menu patches, workspaces) — a real country dump is the proper fix.
Country setup for Tunisia (per the AMP install guide): `amp/TN/TN.txt` (GeoNames `TN.zip`) is mounted as
`doc/gazeteer.csv` and was imported into `amp_locator` (25,850 places) on startup — AMP only imports it while
that table is empty. Global Settings "Country Latitude/Longitude" are set to 34.0 / 9.0. AMP's importer leaves
the admin region codes (`admin1`…) empty. `amp/allCountries/` (1.8 GB, whole world) is not needed.
Note: AMP answers **403** to any page when you are not logged in — that is its login challenge, not an error.

## Start / stop

Run from each folder (`down` keeps data; add `-v` to wipe it):

```sh
# Mifos X
cd mifos-fineract && docker compose -f docker-compose.dpg.yml up -d

# OpenMRS (list files explicitly so the source-build override is skipped)
cd openmrs && docker compose -f docker-compose.yml -f docker-compose.dpg.yml up -d

# DHIS2 (uses dhis2/.env: stable 2.42 image + Sierra Leone demo DB)
cd dhis2 && docker compose -f docker-compose.yml -f docker-compose.dpg.yml up -d

# CKAN (uses ckan/.env)
cd ckan && docker compose up -d
```

## Notes

- **Memory:** Docker has ~8 GB. Fineract ≈ 1.4 GB, OpenMRS ≈ 1.5 GB, CKAN ≈ 1 GB, DHIS2 ≈ 2–3 GB.
  Running everything plus AMP at once will exhaust RAM — stop the ones you're not using.
- **Self-signed HTTPS:** for Mifos, open https://localhost:8443/fineract-provider/actuator/health once
  and accept the certificate warning, otherwise the web UI at :4200 can't log in. Same for CKAN on :8444.
- **First boot is slow:** OpenMRS takes 10–30 min on first start (loads its concept dictionary) and redirects
  to `/openmrs/initialsetup` meanwhile — don't restart it during that time. DHIS2 imports an ~80 MB demo DB
  on first start (several minutes).
- **Windows line endings:** each repo has `core.autocrlf=false` set locally so shell scripts mounted into
  Linux containers keep LF endings; `dhis2` also has `core.longpaths=true`.
- Files added locally (not upstream): `mifos-fineract/docker-compose.dpg.yml`, `openmrs/docker-compose.dpg.yml`,
  `dhis2/docker-compose.dpg.yml`, `dhis2/.env`, `ckan/.env`, `ckan/docker-compose.override.yml`
  (plus `listen 80` enabled in `ckan/nginx/setup/default.conf`).
