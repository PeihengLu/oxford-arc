# pe-hub profile for oxford-arc
#
# Enable in env.sh:
#   export ARC_PROFILE=pe-hub
#   export REPO_ROOT=$DATA/pe-hub
#   export ARC_JOB_PREFIX=pe
#
# Provides:
#   - setup_hooks.sh — install peen/pedb, ViennaRNA, torch, datasets
#   - job_hooks.sh — verify pe_common + peen inside each batch job
#   - rsync_bundles.sh — ONLY=pridict2-repro path expansion
#   - promote_presets.sh, preflight.sh, smoke helpers — local QA before submit
#
# Experiment DAGs (submit_arc_pipeline.sh, submit_arc_matrix.sh) stay in pe-hub
# under scripts/experiments/; they call bin/submit.sh from this toolkit.
