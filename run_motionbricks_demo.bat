@echo off
setlocal EnableExtensions

set "WSL_DISTRO=Ubuntu-22.04"
set "LINUX_REPO=~/GR00T-WholeBodyControl"

echo Starting MotionBricks G1 demo in %WSL_DISTRO%...
echo.

wsl -d %WSL_DISTRO% -- bash -lc "cd %LINUX_REPO% && if [ ! -x .venv_motionbricks/bin/python ]; then echo 'Missing .venv_motionbricks. Run the MotionBricks install steps first.'; exit 1; fi && source .venv_motionbricks/bin/activate && cd motionbricks && python scripts/interactive_demo_g1.py"

set "rc=%ERRORLEVEL%"
echo.
if not "%rc%"=="0" (
    echo MotionBricks demo exited with code %rc%.
    pause
)
exit /b %rc%
