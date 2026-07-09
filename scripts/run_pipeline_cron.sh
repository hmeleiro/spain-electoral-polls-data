#!/usr/bin/env bash
set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "${script_dir}/.." && pwd)"

log_dir="${PIPELINE_LOG_DIR:-${repo_root}/logs}"
mkdir -p "${log_dir}"

run_id="${RUN_ID:-$(date -u +"%Y%m%dT%H%M%SZ")}"
export RUN_ID="${run_id}"

log_file="${log_dir}/pipeline-${run_id}.log"
latest_log="${log_dir}/latest.log"
lock_file="${PIPELINE_LOCK_FILE:-${log_dir}/pipeline.lock}"
rscript_bin="${RSCRIPT_BIN:-Rscript}"

exec >>"${log_file}" 2>&1
ln -sfn "$(basename "${log_file}")" "${latest_log}" 2>/dev/null || true

log() {
  printf '[%s] %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$*"
}

run_step() {
  local label="$1"
  shift

  log "Starting ${label}"
  "$@"
  local status=$?

  if [ "${status}" -ne 0 ]; then
    log "Failed ${label} with exit code ${status}"
    exit "${status}"
  fi

  log "Finished ${label}"
}

run_r_script() {
  local script="$1"

  "${rscript_bin}" -e "source('renv/activate.R'); source('${script}')"
}

exec 9>"${lock_file}"
if command -v flock >/dev/null 2>&1; then
  if ! flock -n 9; then
    log "Another pipeline run is already active; exiting."
    exit 75
  fi
else
  log "flock is not available; continuing without an inter-run lock."
fi

cd "${repo_root}" || exit 1

log "Pipeline run_id=${RUN_ID}"
log "Repository root=${repo_root}"
log "Log file=${log_file}"
log "Rscript=${rscript_bin}"

run_step "build artifacts" run_r_script scripts/build_artifacts.R
run_step "publish artifacts to R2" run_r_script scripts/publish_r2.R

log "Pipeline completed successfully"
