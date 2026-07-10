# Spain Electoral Poll of Polls

ETL repository for building static spain-electoral-polls artifacts for a dashboard.
The canonical data source is the R package `spainpolls`.

## Artifacts

The pipeline writes a stable `latest/` contract and a local immutable
`runs/{run_id}/` copy:

- `polls.parquet`: one row per poll.
- `poll_results.parquet`: one row per poll and party.
- `poll_average_daily.parquet`: daily Kalman average by election and party.
- `poll_deviations.parquet`: poll result plus average and deviation.
- `house_effects.parquet`: pollster-party house effects from a GAM.
- `manifest.json`: run metadata and row counts.
- `validation_report.json`: quality checks used to gate publication.

Percentages are stored as points, not proportions. Missing sample sizes are not
overwritten in public columns; `sample_size_imputed` marks rows where an
internal weight fallback was used.

## Local Run

```sh
Rscript -e "testthat::test_dir('tests/testthat')"
Rscript scripts/build_artifacts.R
```

Local scripts automatically load `.env` from the project root when it exists.
Keep the file in standard `.Renviron`/dotenv format:

```text
KEY=value
```

Useful environment variables:

```text
ARTIFACT_DIR=artifacts
AVERAGE_ELECTION_KEY=congreso_espana_2027
HOUSE_EFFECT_ELECTION_KEYS=congreso_espana_2027,congreso_espana_2023
PARTIES=psoe,pp,vox,sumar,podemos,salf
FILTER_OVERLAPPING_FIELDWORK=true
FRESHNESS_DAYS=45
```

## Publish To Cloudflare R2

Build first, then publish:

```sh
Rscript scripts/build_artifacts.R
Rscript scripts/publish_r2.R
```

Publication uploads only the `latest/` contract to R2. Local `runs/{run_id}/`
copies are not published.

Required environment variables:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_S3_ENDPOINT
R2_BUCKET
```

Optional:

```text
AWS_DEFAULT_REGION=auto
R2_PREFIX=spain-electoral-polls
```

## Cron

On a VM, schedule the full build-and-publish pipeline with:

```sh
bash /path/to/poll-of-polls-data/scripts/run_pipeline_cron.sh
```

The entrypoint writes timestamped logs to `logs/` and updates `logs/latest.log`.
It uses `.env` from the repository root through the underlying R scripts.

In production, this pipeline is normally triggered by
`spain-electoral-polls-etl/scripts/run_scraper_cron.sh` after a successful new
Wikipedia revision. Do not keep an independent six-hour cron enabled in that
setup, otherwise the dashboard artifacts may be rebuilt even when the source
database has not changed.

For standalone/manual deployments, a sample crontab entry is:

```cron
0 */6 * * * cd /path/to/poll-of-polls-data && bash scripts/run_pipeline_cron.sh
```

Optional environment variables:

```text
PIPELINE_LOG_DIR=/var/log/spain-electoral-polls
PIPELINE_LOCK_FILE=/tmp/spain-electoral-polls.lock
RSCRIPT_BIN=/usr/local/bin/Rscript
RUN_ID=20260709T120000Z
```

## CI/CD

GitHub Actions deploys the repository contents to the VM on every push. The VM
then runs the pipeline through cron.

Required GitHub Actions secrets:

```text
DEPLOY_HOST=example.com
DEPLOY_USER=deploy
DEPLOY_PORT=22
DEPLOY_PATH=/srv/spain-electoral-polls/poll-of-polls-data
DEPLOY_SSH_KEY=<private SSH key with access to DEPLOY_USER@DEPLOY_HOST>
```

Optional but recommended:

```text
DEPLOY_KNOWN_HOSTS=<ssh-keyscan output for the remote host>
```

The deploy uses `rsync --delete`, but excludes local/runtime state such as
`.env`, `.Renviron`, `artifacts/`, `logs/`, `.git/`, and `renv/library/`, so
secrets and generated outputs should live on the VM and will not be overwritten
by GitHub Actions.

The VM needs SSH access for `DEPLOY_USER`, `rsync` installed, R available on the
cron user's `PATH`, and a local `.env` file in `DEPLOY_PATH` with the R2/API
configuration.

After the first deploy, restore packages from the project root on the VM:

```sh
cd /srv/spain-electoral-polls/poll-of-polls-data
Rscript scripts/bootstrap_renv_vm.R
Rscript -e "source('renv/activate.R'); print(.libPaths()); renv::status()"
```

The first `.libPaths()` entry should point to this project's `renv` library or
renv cache. If you open an interactive R session manually, start it from
`DEPLOY_PATH` so `.Rprofile` can activate `renv`.

If `renv::restore()` tries to install `nanonext 1.10.0` while `renv.lock`
expects `1.8.1`, use `scripts/bootstrap_renv_vm.R`; it installs `nanonext` and
`mirai` from explicit CRAN Archive URLs before restoring the rest.
