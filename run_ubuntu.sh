#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON:-python3}"

cd "$ROOT_DIR"

print_help() {
    cat <<'EOF'
GR00T-WholeBodyControl Ubuntu runner

Usage:
  ./run_ubuntu.sh                         Open menu
  ./run_ubuntu.sh help                    Show this help
  ./run_ubuntu.sh doctor                  Run environment check
  ./run_ubuntu.sh doctor-training         Run training environment check
  ./run_ubuntu.sh doctor-deploy           Run deployment environment check
  ./run_ubuntu.sh setup-ubuntu            Install common Ubuntu system packages
  ./run_ubuntu.sh lfs                     Pull Git LFS assets
  ./run_ubuntu.sh download-models         Download default Hugging Face assets
  ./run_ubuntu.sh download-low-latency    Download low-latency SONIC assets
  ./run_ubuntu.sh install-sim             Install MuJoCo sim environment
  ./run_ubuntu.sh install-teleop          Install PICO / teleop environment
  ./run_ubuntu.sh install-data            Install data collection environment
  ./run_ubuntu.sh install-inference       Install VLA inference environment
  ./run_ubuntu.sh install-motionbricks    Install MotionBricks package
  ./run_ubuntu.sh sim-loop [args]         Run gear_sonic/scripts/run_sim_loop.py
  ./run_ubuntu.sh deploy-sim [args]       Run gear_sonic_deploy/deploy.sh sim
  ./run_ubuntu.sh keyboard-sim [args]     Run deploy.sh --input-type keyboard sim
  ./run_ubuntu.sh manager-sim [args]      Run deploy.sh --input-type zmq_manager sim
  ./run_ubuntu.sh pico [args]             Run pico_manager_thread_server.py --manager
  ./run_ubuntu.sh vla-sim [args]          Run launch_inference.py --sim
  ./run_ubuntu.sh motionbricks [args]     Run MotionBricks G1 interactive demo
  ./run_ubuntu.sh test                    Run decoupled_wbc tests
  ./run_ubuntu.sh lint                    Run lint checks
  ./run_ubuntu.sh docs                    Build Sphinx docs

Notes:
  - For the normal sim flow, use two terminals:
      Terminal 1: ./run_ubuntu.sh sim-loop
      Terminal 2: ./run_ubuntu.sh deploy-sim
  - Press ] in the deploy terminal when deploy.sh asks to start the policy.
  - Set PYTHON=/path/to/python before running to use a specific Python.
EOF
}

need_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing command: $1"
        return 1
    fi
}

run_python() {
    need_cmd "$PYTHON_BIN"
    "$PYTHON_BIN" "$@"
}

venv_python_or_default() {
    local venv_python="$1"
    shift
    if [[ -x "$venv_python" ]]; then
        "$venv_python" "$@"
    else
        run_python "$@"
    fi
}

setup_ubuntu() {
    need_cmd sudo
    sudo apt-get update
    sudo apt-get install -y \
        build-essential \
        cmake \
        git \
        git-lfs \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        ffmpeg \
        libgl1 \
        libglib2.0-0 \
        libx11-6 \
        libxext6 \
        libxrender1 \
        libsm6
    git lfs install
}

pull_lfs() {
    need_cmd git
    git lfs install
    git lfs pull
}

download_models() {
    run_python -m pip install -q huggingface_hub
    run_python download_from_hf.py "$@"
}

run_install_script() {
    local script="$1"
    if [[ ! -f "$script" ]]; then
        echo "Install script not found: $script"
        exit 1
    fi
    bash "$script"
}

run_deploy() {
    if [[ ! -f gear_sonic_deploy/deploy.sh ]]; then
        echo "gear_sonic_deploy/deploy.sh not found"
        exit 1
    fi
    (cd gear_sonic_deploy && bash deploy.sh "$@")
}

run_motionbricks() {
    if [[ ! -d motionbricks ]]; then
        echo "motionbricks/ not found"
        exit 1
    fi
    if [[ ! -x ".venv_motionbricks/bin/python" ]]; then
        echo "MotionBricks venv not found: .venv_motionbricks"
        echo "Create it first, then install MotionBricks into it."
        exit 1
    fi
    (cd motionbricks && "../.venv_motionbricks/bin/python" scripts/interactive_demo_g1.py "$@")
}

open_menu() {
    while true; do
        clear || true
        cat <<'EOF'
GR00T-WholeBodyControl Ubuntu runner

  1. Check environment
  2. Setup Ubuntu system packages
  3. Pull Git LFS assets
  4. Download default models from Hugging Face
  5. Install MuJoCo sim environment
  6. Run MuJoCo sim loop
  7. Run deploy.sh sim
  8. Run keyboard sim deploy
  9. Run PICO / ZMQ manager
 10. Run VLA inference in sim
 11. Install MotionBricks
 12. Run MotionBricks G1 demo
 13. Run tests
 14. Help
  0. Exit

EOF
        read -r -p "Select: " choice
        case "$choice" in
            1) run_python check_environment.py; pause ;;
            2) setup_ubuntu; pause ;;
            3) pull_lfs; pause ;;
            4) download_models; pause ;;
            5) run_install_script install_scripts/install_mujoco_sim.sh; pause ;;
            6) venv_python_or_default ".venv_sim/bin/python" gear_sonic/scripts/run_sim_loop.py; pause ;;
            7) run_deploy sim; pause ;;
            8) run_deploy --input-type keyboard sim; pause ;;
            9) venv_python_or_default ".venv_teleop/bin/python" gear_sonic/scripts/pico_manager_thread_server.py --manager; pause ;;
            10) venv_python_or_default ".venv_inference/bin/python" gear_sonic/scripts/launch_inference.py --sim; pause ;;
            11) (cd motionbricks && run_python -m pip install -e .); pause ;;
            12) run_motionbricks; pause ;;
            13) run_python -m pytest decoupled_wbc/tests; pause ;;
            14) print_help; pause ;;
            0) exit 0 ;;
            *) echo "Invalid selection"; pause ;;
        esac
    done
}

pause() {
    echo
    read -r -p "Press Enter to continue..." _
}

cmd="${1:-menu}"
if [[ "$#" -gt 0 ]]; then
    shift
fi

case "$cmd" in
    menu) open_menu ;;
    help|--help|-h) print_help ;;
    doctor|check) run_python check_environment.py ;;
    doctor-training|check-training) run_python check_environment.py --training ;;
    doctor-deploy|check-deploy) run_python check_environment.py --deploy ;;
    setup-ubuntu) setup_ubuntu ;;
    lfs) pull_lfs ;;
    download-models) download_models "$@" ;;
    download-low-latency) download_models --low-latency "$@" ;;
    install-sim) run_install_script install_scripts/install_mujoco_sim.sh ;;
    install-teleop) run_install_script install_scripts/install_pico.sh ;;
    install-data) run_install_script install_scripts/install_data_collection.sh ;;
    install-inference) run_install_script install_scripts/install_inference.sh ;;
    install-motionbricks) (cd motionbricks && run_python -m pip install -e .) ;;
    sim-loop|sim) venv_python_or_default ".venv_sim/bin/python" gear_sonic/scripts/run_sim_loop.py "$@" ;;
    deploy-sim) run_deploy sim "$@" ;;
    keyboard-sim) run_deploy --input-type keyboard sim "$@" ;;
    manager-sim) run_deploy --input-type zmq_manager sim "$@" ;;
    pico) venv_python_or_default ".venv_teleop/bin/python" gear_sonic/scripts/pico_manager_thread_server.py --manager "$@" ;;
    vla-sim) venv_python_or_default ".venv_inference/bin/python" gear_sonic/scripts/launch_inference.py --sim "$@" ;;
    motionbricks) run_motionbricks "$@" ;;
    test) run_python -m pytest decoupled_wbc/tests ;;
    lint) bash lint.sh "$@" ;;
    docs) (cd docs && make html) ;;
    *)
        echo "Unknown command: $cmd"
        echo
        print_help
        exit 1
        ;;
esac
