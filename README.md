# Oxford ARC toolkit

Reusable scripts for working with [Oxford ARC](https://arc-user-guide.readthedocs.io/en/latest/)
(HTC GPU cluster): SLURM submit wrappers, conda/module job env, laptop ↔ cluster
rsync of DVC-tracked artifacts, and optional project profiles.

**No personal accounts, emails, or `/data/.../$USER` paths are committed.**
Copy `env.sh.example` → `env.sh` (gitignored) and fill in your own values.

Official docs: [ARC User Guide](https://arc-user-guide.readthedocs.io/en/latest/)

## Layout

| Path | Role |
|------|------|
| `bin/submit.sh` | Submit a stage script to HTC with GPU defaults |
| `bin/pull.sh` / `bin/push.sh` | Rsync DVC outs + `env.sh` (one SSH prompt) |
| `bin/setup_interactive.sh` | Bootstrap conda env on an interactive GPU node |
| `bin/setup_dvc_remote.sh` | Write local DVC `arc` remote URL |
| `lib/job_env.sh` | Module load + conda activate (PATH pin vs Anaconda module) |
| `lib/run_stage.sbatch` | Generic SLURM batch wrapper |
| `profiles/pe-hub/` | Optional hooks for the pe-hub project |
| `env.sh.example` | Template — copy to `env.sh`, never commit |

## Quick start

1. Clone this toolkit somewhere convenient (sibling to your project is fine).
2. Configure:

   ```bash
   cp env.sh.example env.sh
   # edit: REPO_ROOT, ARC_PROJECT, CONDA_ENV, optional ARC_PROFILE / ARC_MAIL_USER
   ```

3. On ARC (interactive GPU node), bootstrap:

   ```bash
   srun -p interactive --gres=gpu:1 --cpus-per-task=4 --mem=16G --time=02:00:00 --pty bash
   export REPO_ROOT=$DATA/my-project
   bash /path/to/oxford-arc/bin/setup_interactive.sh
   ```

4. Submit from `htc-login` (not the login node for heavy work — scheduler only):

   ```bash
   ./bin/submit.sh path/to/stage.sh
   DRY_RUN=1 ./bin/submit.sh path/to/stage.sh
   ```

5. Sync artifacts from your laptop (VPN or ProxyJump — see `examples/ssh_config.snippet`):

   ```bash
   ./bin/pull.sh                # prompts for ARC username
   ./bin/push.sh YOUR_ARC_USER
   ONLY=env ./bin/pull.sh YOUR_ARC_USER
   ```

## Cluster facts (HTC)

| Need | Choice |
|------|--------|
| Cluster | `htc` (`htc-login.arc.ox.ac.uk`) |
| On Uni net / VPN | `ssh YOU@htc-login.arc.ox.ac.uk` |
| Off-net | `ssh YOU@gateway.arc.ox.ac.uk` then hop to `htc-login` |
| Repo + data | `$DATA/...` (project share). Avoid `$HOME` (~15 GiB) for envs/datasets |
| Conda | `module load Anaconda3` (or Mamba); env **prefix** under `$DATA/envs/…` |
| Partitions | `short` ≤12h · `medium` ≤48h · `long` ≤30d · `devel` 10m test |
| GPU | `#SBATCH --gres=gpu:1` (+ optional `--constraint='gpu_sku:L40S'`) |
| Build / pip / conda | **interactive** node: `srun -p interactive --gres=gpu:1 --pty bash` |

## Using with pe-hub

```bash
# env.sh
export REPO_ROOT=$DATA/pe-hub
export ARC_PROFILE=pe-hub
export ARC_JOB_PREFIX=pe
export ARC_PROJECT=YOUR_ARC_PROJECT   # your group share under /data/
export CONDA_ENV=$DATA/envs/pe-hub
```

Then:

```bash
./bin/setup_interactive.sh          # installs peen / pedb via profile hooks
./bin/submit.sh 01_tune_base_library1.sh
./profiles/pe-hub/preflight.sh       # local mini-data pipeline before ARC
```

Experiment DAGs (`submit_arc_pipeline.sh`, `submit_arc_matrix.sh`) remain in
pe-hub under `scripts/experiments/`; point them at this toolkit’s `bin/submit.sh`
(see pe-hub migration note below).

### Nested install (optional)

You can also place this repo at `<pe-hub>/scripts/cluster/oxford-arc` (submodule
or vendor copy). In that layout `REPO_ROOT` is inferred automatically.

## Privacy

- `env.sh` is gitignored — keep usernames, emails, and absolute data paths there only.
- Examples use placeholders (`YOUR_ARC_USER`, `YOUR_ARC_PROJECT`).
- Do not commit `.dvc/config.local`, SSH keys, or mail addresses.

## Monitor

```bash
squeue --clusters=htc -u $USER
scancel --clusters=htc <jobid>
tail -f $REPO_ROOT/slurm-<jobid>.out
```

## Tests

```bash
./bin/test_job_env_path.sh
```

## Migration from pe-hub embedded scripts

Older pe-hub checkouts kept these files under `scripts/cluster/oxford-arc/`.
That tree can become a thin wrapper or submodule pointing here. Keep a local
`env.sh` (never shared) with your `ARC_PROJECT`, `REPO_ROOT`, and optional
`ARC_MAIL_USER`.
