@echo off
setlocal EnableExtensions

pushd "%~dp0" >nul

if "%PYTHON%"=="" set "PYTHON=python"

if "%~1"=="" goto menu
if /I "%~1"=="menu" goto menu
if /I "%~1"=="help" goto help
if /I "%~1"=="--help" goto help
if /I "%~1"=="/?" goto help
if /I "%~1"=="check" goto check
if /I "%~1"=="check-training" goto check_training
if /I "%~1"=="check-deploy" goto check_deploy
if /I "%~1"=="install-sim" goto install_sim
if /I "%~1"=="install-teleop" goto install_teleop
if /I "%~1"=="install-motionbricks" goto install_motionbricks
if /I "%~1"=="sim" goto sim
if /I "%~1"=="pico" goto pico
if /I "%~1"=="vla" goto vla
if /I "%~1"=="motionbricks" goto motionbricks
if /I "%~1"=="deploy-sim" goto deploy_sim
if /I "%~1"=="deploy-keyboard-sim" goto deploy_keyboard_sim
if /I "%~1"=="docs" goto docs
if /I "%~1"=="lint" goto lint
if /I "%~1"=="test" goto test

echo Unknown command: %~1
echo.
goto help

:menu
cls
echo GR00T-WholeBodyControl runner
echo.
echo  1. Check environment
echo  2. Install MuJoCo sim Python deps
echo  3. Run MuJoCo sim loop
echo  4. Run PICO / ZMQ manager
echo  5. Run VLA inference launcher
echo  6. Run MotionBricks G1 demo
echo  7. Run deploy.sh sim via bash
echo  8. Run tests
echo  9. Help
echo  0. Exit
echo.
set /p choice=Select: 

if "%choice%"=="1" goto check
if "%choice%"=="2" goto install_sim
if "%choice%"=="3" goto sim
if "%choice%"=="4" goto pico
if "%choice%"=="5" goto vla
if "%choice%"=="6" goto motionbricks
if "%choice%"=="7" goto deploy_sim
if "%choice%"=="8" goto test
if "%choice%"=="9" goto help
if "%choice%"=="0" goto end
echo Invalid selection.
pause
goto menu

:help
echo GR00T-WholeBodyControl runner
echo.
echo Usage:
echo   run.bat                         Open menu
echo   run.bat check                   Run python check_environment.py
echo   run.bat check-training          Run training environment checks
echo   run.bat check-deploy            Run deployment environment checks
echo   run.bat install-sim             Install gear_sonic sim dependencies
echo   run.bat install-teleop          Install gear_sonic teleop dependencies
echo   run.bat install-motionbricks    Install MotionBricks dependencies
echo   run.bat sim [args]              Run gear_sonic/scripts/run_sim_loop.py
echo   run.bat pico [args]             Run pico_manager_thread_server.py --manager
echo   run.bat vla [args]              Run launch_inference.py
echo   run.bat motionbricks [args]     Run MotionBricks G1 demo
echo   run.bat deploy-sim [args]       Run gear_sonic_deploy/deploy.sh sim via bash
echo   run.bat deploy-keyboard-sim     Run deploy.sh --input-type keyboard sim via bash
echo   run.bat docs                    Build Sphinx docs
echo   run.bat lint                    Run lint.sh via bash
echo   run.bat test                    Run decoupled_wbc pytest suite
echo.
echo Notes:
echo   - Set PYTHON before running to use a specific interpreter:
echo       set PYTHON=C:\path\to\python.exe
echo   - deploy.sh and lint.sh need bash. Use Git Bash, WSL, or Linux for those commands.
echo   - Real robot deployment is not launched from this Windows helper by default.
goto end

:check_python
%PYTHON% --version >nul 2>nul
if errorlevel 1 (
    echo Python not found. Install Python 3.10+ or set PYTHON to your interpreter.
    exit /b 1
)
exit /b 0

:check_bash
set "BASH_EXE="
set "WSL_BASH="
for /f "delims=" %%B in ('where bash 2^>nul') do (
    if /I "%%B"=="C:\Windows\System32\bash.exe" (
        set "WSL_BASH=%%B"
    ) else (
        if not defined BASH_EXE set "BASH_EXE=%%B"
    )
)
if not defined BASH_EXE (
    if defined WSL_BASH (
        echo Windows WSL bash was found, but no Git Bash executable was found.
        echo Install a WSL distro or Git Bash, then try again.
        exit /b 1
    )
    echo bash not found. Install Git Bash/WSL or run this command on Linux.
    exit /b 1
)
"%BASH_EXE%" -lc "echo ok" >nul 2>nul
if errorlevel 1 (
    echo bash was found, but it is not usable from this CMD session.
    echo Install a WSL distro or Git Bash, then try again.
    exit /b 1
)
exit /b 0

:check
call :check_python
if errorlevel 1 goto fail
%PYTHON% check_environment.py
goto done

:check_training
call :check_python
if errorlevel 1 goto fail
%PYTHON% check_environment.py --training
goto done

:check_deploy
call :check_python
if errorlevel 1 goto fail
%PYTHON% check_environment.py --deploy
goto done

:install_sim
call :check_python
if errorlevel 1 goto fail
%PYTHON% -m pip install -e "gear_sonic[sim]"
goto done

:install_teleop
call :check_python
if errorlevel 1 goto fail
%PYTHON% -m pip install -e "gear_sonic[teleop]"
goto done

:install_motionbricks
call :check_python
if errorlevel 1 goto fail
pushd motionbricks
%PYTHON% -m pip install -e .
set "rc=%ERRORLEVEL%"
popd
exit /b %rc%

:sim
call :check_python
if errorlevel 1 goto fail
shift
%PYTHON% gear_sonic\scripts\run_sim_loop.py %*
goto done

:pico
call :check_python
if errorlevel 1 goto fail
shift
%PYTHON% gear_sonic\scripts\pico_manager_thread_server.py --manager %*
goto done

:vla
call :check_python
if errorlevel 1 goto fail
shift
%PYTHON% gear_sonic\scripts\launch_inference.py %*
goto done

:motionbricks
call :check_python
if errorlevel 1 goto fail
shift
pushd motionbricks
%PYTHON% scripts\interactive_demo_g1.py %*
set "rc=%ERRORLEVEL%"
popd
exit /b %rc%

:deploy_sim
shift
call :check_bash
if errorlevel 1 goto fail
pushd gear_sonic_deploy
"%BASH_EXE%" deploy.sh sim %*
set "rc=%ERRORLEVEL%"
popd
exit /b %rc%

:deploy_keyboard_sim
call :check_bash
if errorlevel 1 goto fail
pushd gear_sonic_deploy
"%BASH_EXE%" deploy.sh --input-type keyboard sim
set "rc=%ERRORLEVEL%"
popd
exit /b %rc%

:docs
where make >nul 2>nul
if errorlevel 1 (
    echo make not found. Install make or build docs manually with sphinx-build.
    goto fail
)
pushd docs
make html
set "rc=%ERRORLEVEL%"
popd
exit /b %rc%

:lint
call :check_bash
if errorlevel 1 goto fail
"%BASH_EXE%" lint.sh
goto done

:test
call :check_python
if errorlevel 1 goto fail
%PYTHON% -m pytest decoupled_wbc\tests
goto done

:done
set "rc=%ERRORLEVEL%"
if not "%rc%"=="0" goto fail_with_code
goto end

:fail
popd >nul
exit /b 1

:fail_with_code
popd >nul
exit /b %rc%

:end
popd >nul
exit /b 0
