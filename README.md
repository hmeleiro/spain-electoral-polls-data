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

## CI/CD

GitHub Actions restores `renv`, runs tests, builds artifacts on every push, and
publishes to R2 on `main`, scheduled runs, and manual `workflow_dispatch` runs.
