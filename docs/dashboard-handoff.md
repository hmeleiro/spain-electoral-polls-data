# Dashboard Handoff: Spain Electoral Poll of Polls

## Published Data Contract

Current schema version: `1.0.0`.

Cloudflare R2 object layout:

```text
spain-electoral-polls/latest/manifest.json
spain-electoral-polls/latest/validation_report.json
spain-electoral-polls/latest/polls.parquet
spain-electoral-polls/latest/poll_results.parquet
spain-electoral-polls/latest/poll_average_daily.parquet
spain-electoral-polls/latest/poll_deviations.parquet
spain-electoral-polls/latest/house_effects.parquet
```

Use `latest/` for the dashboard. Immutable `runs/{run_id}` copies may exist
locally after builds, but they are not published to Cloudflare R2.

The latest local manifest at handoff time reports:

```text
generated_at: 2026-07-07T15:42:44Z
run_id: 20260707T154211Z
source: spainpolls
average_election_key: congreso_espana_2027
house_effect_election_keys: congreso_espana_2027, congreso_espana_2023
parties: psoe, pp, vox, sumar
latest_fieldwork_end: 2026-07-04
validation_status: passed
```

Row counts at handoff time:

```text
polls: 508
poll_results: 2032
poll_average_daily: 4304
poll_deviations: 2032
house_effects: 108
```

Always load `manifest.json` first. Render the dashboard only when
`validation_status == "passed"` and the `schema_version` is supported.

## Artifact Schemas

### `polls.parquet`

Granularity: one row per poll.

Columns:

```text
poll_id: character
election_key: character
pollster_key: character
pollster_name: character
media: character
fieldwork_start: date, can be null
fieldwork_end: date
publication_date: date, can be null
sample_size: numeric, can be null
sample_size_imputed: logical
source_url: character, can be null
source_title: character, can be null
```

Use this table for poll cards, poll metadata, pollster/media filters, and
latest-poll lists.

### `poll_results.parquet`

Granularity: one row per poll and party.

Columns:

```text
poll_id: character
election_key: character
pollster_key: character
pollster_name: character
media: character
fieldwork_start: date, can be null
fieldwork_end: date
publication_date: date, can be null
date: date
sample_size: numeric, can be null
sample_size_imputed: logical
party_key: character
party_name: character
short_name: character
color_hex: character
vote_share: numeric
```

Percentages are stored in percentage points, not 0-1 proportions. A value of
`28.4` means `28.4%`.

Use this table for raw poll points, poll-detail tables, and party filters.

### `poll_average_daily.parquet`

Granularity: one row per election, party, and day.

Columns:

```text
election_key: character
party_key: character
date: date
average_vote_share: numeric
n_polls_day: integer
```

`average_vote_share` is the daily Kalman smoothed spain-electoral-polls estimate.
`n_polls_day` is the number of observed poll rows for that party/date; it is
`0` on days filled by the daily grid.

Use this table for the main trend lines.

### `poll_deviations.parquet`

Granularity: one row per poll and party, enriched with the same-day average.

Columns:

```text
poll_id: character
election_key: character
pollster_key: character
pollster_name: character
media: character
fieldwork_start: date, can be null
fieldwork_end: date
publication_date: date, can be null
date: date
sample_size: numeric, can be null
sample_size_imputed: logical
party_key: character
party_name: character
short_name: character
color_hex: character
vote_share: numeric
average_vote_share: numeric
deviation_from_average: numeric
```

Use this table when showing how far a poll result is above or below the
spain-electoral-polls average.

### `house_effects.parquet`

Granularity: one row per pollster and party.

Columns:

```text
pollster_key: character
party_key: character
house_effect: numeric
se: numeric
ic_low: numeric
ic_high: numeric
n: integer
house_effect_status: character
```

`house_effect`, `ic_low`, and `ic_high` are percentage-point deviations.
`house_effect_status` is one of:

```text
positive
negative
unclear
```

Use this table for house-effect rankings, confidence intervals, and pollster
profile panels.

## Non-Goals

- Do not implement polling-data scraping in the dashboard.
- Do not run the R models in the dashboard.
- Do not write back to R2 from the dashboard.
- Do not rely on immutable `runs/{run_id}` objects in Cloudflare R2.
