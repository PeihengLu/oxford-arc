#!/usr/bin/env bash
# pe-hub profile: interactive-node bootstrap after conda env exists.
# Sourced by bin/setup_interactive.sh when ARC_PROFILE=pe-hub.

arc_profile_setup() {
    local python_pin="${PYTHON_PIN:-python=3.11.*}"

    _verify_conda_python_311() {
        local ver minor
        ver="$(python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")')"
        minor="$(python -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
        if [[ "${minor}" != "3.11" ]]; then
            echo "Error: ${CONDA_ENV} has Python ${ver}; pe-hub requires 3.11.x." >&2
            echo "Remove the env and re-run setup_interactive.sh:" >&2
            echo "  conda deactivate && rm -rf \"${CONDA_ENV}\"" >&2
            exit 1
        fi
    }

    _verify_conda_python_311

    echo "Installing ViennaRNA (bioconda) if missing…"
    if ! python -c "import RNA" 2>/dev/null; then
        conda install -y -c bioconda -c conda-forge "${python_pin}" viennarna
        _verify_conda_python_311
    fi

    echo "Installing PyTorch (CUDA wheel). Adjust cu121/cu124 if needed for the node driver…"
    python -c "import torch; assert torch.cuda.is_available()" 2>/dev/null || \
        pip install "torch>=2.0,<2.9" --index-url https://download.pytorch.org/whl/cu124

    cd "${REPO_ROOT}"
    ./scripts/install-clis.sh

    if ! command -v dvc >/dev/null 2>&1; then
        echo "Installing dvc…"
        pip install 'dvc[ssh]'
    fi

    echo "Seeding / preparing datasets if needed (may take a while)…"
    if [[ ! -d "${REPO_ROOT}/datasets/standardized" ]]; then
        pedb init || true
    fi

    echo ""
    echo "Smoke-check:"
    peen devices
    python - <<'PY'
import torch
print("torch", torch.__version__, "cuda", torch.cuda.is_available(),
      torch.cuda.get_device_name(0) if torch.cuda.is_available() else "n/a")
PY
}
