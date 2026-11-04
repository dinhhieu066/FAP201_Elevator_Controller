@echo off
chcp 65001 >nul
title Elevator Controller Simulation - FAP201

echo =========================================================================
echo       FAP201 - ELEVATOR CONTROLLER AUTOMATED SIMULATION & VERIFICATION   
echo =========================================================================
echo.

cd /d "%~dp0"

echo [STEP 1] Generating Testcases and Golden Model Expected Outputs...
python ..\golden_model\run_golden_model.py
if errorlevel 1 (
    echo [ERROR] Golden Model generation failed!
    pause
    exit /b 1
)

echo.
echo [STEP 2] Running ModelSim RTL Simulation in Batch Mode...
vsim -c -do run_sim.do
if errorlevel 1 (
    echo [ERROR] ModelSim simulation failed!
    pause
    exit /b 1
)

echo.
echo [STEP 3] Comparing RTL Output against Golden Model...
python ..\golden_model\verify_results.py
if errorlevel 1 (
    echo [ERROR] Verification failed! Mismatches found.
    pause
    exit /b 1
)

echo.
echo =========================================================================
echo   [SUCCESS] SIMULATION AND 100%% VERIFICATION COMPLETED SUCCESSFULLY!
echo =========================================================================
echo.
pause
