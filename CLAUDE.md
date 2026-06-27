# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Project Overview

GR00T-WholeBodyControl is a robotics monorepo for NVIDIA whole-body control work:

- `gear_sonic/`: SONIC Python stack for training, teleoperation, MuJoCo simulation, data collection, camera server, and VLA inference.
- `gear_sonic_deploy/`: C++ deployment stack for SONIC policies on Unitree G1 hardware and simulation.
- `decoupled_wbc/`: Decoupled WBC controller package and tests used by GR00T N1.5/N1.6.
- `motionbricks/`: MotionBricks Python package, demos, pretrained checkpoint layout, and training scripts.
- `docs/`: Sphinx documentation source.
- `external_dependencies/`: vendored third-party SDKs and generated/vendor code. Avoid broad edits here unless the task is explicitly about that dependency.

The repository contains Git LFS assets such as meshes, ONNX models, and checkpoints. Do not rewrite, format, or remove binary/model assets unless the user explicitly asks.

## Environment Notes

- Python packages target Python 3.10+, but SONIC training follows Isaac Lab requirements and expects Python 3.11.
- Git LFS is required. If assets look like tiny pointer files, run `git lfs pull` from the repo root before debugging runtime failures.
- Installation is split by use case rather than one global environment.
- On this machine, the working Linux clone is under Ubuntu WSL at `~/GR00T-WholeBodyControl`. Prefer that clone for running installs, MuJoCo, MotionBricks, and deployment.
- Do not run active installs from `/mnt/d/AI/motionbricks/GR00T-WholeBodyControl`; that Windows-mounted clone is useful for copying patches/scripts but has caused permission and editable-install issues.
- Do not use the WSL `root` user for normal work. Enter WSL from Windows with `wsl -d Ubuntu-22.04` and work as `cem_akgun`.
- Use separate virtual environments:
  - `.venv_sim` for `gear_sonic` MuJoCo simulation and deployment helper scripts.
  - `.venv_motionbricks` for MotionBricks interactive demos.

Common installs:

```bash
pip install -e "gear_sonic[sim]"
pip install -e "gear_sonic[teleop]"
pip install -e "gear_sonic[data_collection]"
pip install -e "gear_sonic[inference]"
pip install -e "gear_sonic[training]"
pip install -e "decoupled_wbc[full]"
pip install -e "decoupled_wbc[dev]"
cd motionbricks && pip install -e .
```

Install scripts create purpose-specific environments:

```bash
bash install_scripts/install_mujoco_sim.sh
bash install_scripts/install_pico.sh
bash install_scripts/install_data_collection.sh
bash install_scripts/install_camera_server.sh
bash install_scripts/install_inference.sh
```

## Local Runbook

Use the Ubuntu home clone:

```bash
cd ~/GR00T-WholeBodyControl
```

Run the MuJoCo simulation loop:

```bash
cd ~/GR00T-WholeBodyControl
./run_ubuntu.sh sim-loop
```

Run the MotionBricks interactive G1 demo:

```bash
cd ~/GR00T-WholeBodyControl
source .venv_motionbricks/bin/activate
cd motionbricks
python scripts/interactive_demo_g1.py
```

Run the C++ deploy simulation in a second terminal while `sim-loop` is still running:

```bash
cd ~/GR00T-WholeBodyControl
export TensorRT_ROOT=/usr
./run_ubuntu.sh deploy-sim
```

If deploy prints `LowState is not available, waiting for robot to be ready`, keep or restart the MuJoCo `sim-loop` in another terminal. Deploy is waiting for simulated robot state messages.

## Local Model Assets

MotionBricks checkpoints are Git LFS assets. If PyTorch fails with `invalid load key, 'v'`, the checkpoint is still a Git LFS pointer. From the repo root:

```bash
git lfs fetch --all
git lfs checkout
```

GEAR-SONIC deploy ONNX files are downloaded from Hugging Face, not Git LFS:

```bash
cd ~/GR00T-WholeBodyControl
source .venv_sim/bin/activate
uv pip install --python .venv_sim/bin/python huggingface_hub
python download_from_hf.py
```

Expected deploy files:

```text
gear_sonic_deploy/policy/release/model_encoder.onnx
gear_sonic_deploy/policy/release/model_decoder.onnx
gear_sonic_deploy/planner/target_vel/V2/planner_sonic.onnx
```

## Local TensorRT Notes

TensorRT is installed system-wide and `TensorRT_ROOT=/usr` is used for deploy builds. The local C++ deploy code has a TensorRT 10+ compatibility patch in `gear_sonic_deploy/src/TRTInference/InferenceEngine.cpp`:

- TensorRT 10+ uses `createNetworkV2(0U)` instead of the removed `kEXPLICIT_BATCH` flag.
- Shape tensor profiles use `setShapeValuesV2`.
- Deprecated FP16 builder flag usage is skipped for TensorRT 10+.

If a clean Ubuntu clone is used, copy this patched file from the Windows repo before building deploy:

```bash
cp /mnt/d/AI/motionbricks/GR00T-WholeBodyControl/gear_sonic_deploy/src/TRTInference/InferenceEngine.cpp \
   ~/GR00T-WholeBodyControl/gear_sonic_deploy/src/TRTInference/InferenceEngine.cpp
```

## Development Commands

Run environment checks from the repo root:

```bash
python check_environment.py
python check_environment.py --training
python check_environment.py --deploy
```

Formatting and linting:

```bash
make run-checks
make format
bash lint.sh
bash lint.sh --fix
```

Focused tests:

```bash
pytest decoupled_wbc/tests
pytest decoupled_wbc/tests/control
pytest decoupled_wbc/tests/sim
```

Documentation:

```bash
cd docs
pip install -r requirements.txt
make html
```

## Code Style

- Use the existing Python style. Root tooling config uses Black, isort, Ruff, and mypy settings in `pyproject.toml`.
- Root Black line length is 100; Ruff line length is 115. Follow nearby code when they differ.
- Keep imports sorted with the configured Ruff/isort rules.
- Avoid unrelated refactors in robotics control paths; small numerical or timing changes can alter behavior.
- Add tests or replay checks for changes in controller logic, interpolation, robot model handling, policy code, or data exporters.
- Update docs when changing user-facing commands, setup steps, ZMQ protocol behavior, deployment flags, or dataset formats.

## Robotics-Specific Caution

- Treat deployment, robot model, motion library, ZMQ, and TensorRT/ONNX changes as high risk.
- Preserve frame conventions, joint ordering, observation dimensions, action dimensions, and checkpoint path semantics unless the task explicitly changes them.
- In `gear_sonic_deploy/`, prefer minimal C++ changes and verify build/deploy commands that are practical in the current environment.
- Do not assume real robot hardware, Isaac Lab, CUDA, TensorRT, PICO devices, or cameras are available locally.

## Large Files and Generated Content

- Do not run formatters over `external_dependencies/`, generated vendor trees, mesh directories, model checkpoints, or LFS-managed assets.
- Avoid committing runtime outputs, logs, local venvs, and generated build directories.
- `motionbricks/out/**` contains opt-in pretrained checkpoints and should not be changed for normal source edits.
