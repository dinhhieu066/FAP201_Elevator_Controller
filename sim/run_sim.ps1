# =============================================================================
# PowerShell Simulation Script: run_sim.ps1
# Project: Elevator Controller (FAP201)
# =============================================================================

Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host "       FAP201 - ELEVATOR CONTROLLER AUTOMATED SIMULATION & VERIFICATION   " -ForegroundColor Cyan
Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "[STEP 1] Generating Testcases and Golden Model Expected Outputs..." -ForegroundColor Yellow
python ..\golden_model\run_golden_model.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Golden Model generation failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[STEP 2] Running ModelSim RTL Simulation in Batch Mode..." -ForegroundColor Yellow
vsim -c -do run_sim.do
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] ModelSim simulation failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[STEP 3] Comparing RTL Output against Golden Model..." -ForegroundColor Yellow
python ..\golden_model\verify_results.py
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Verification failed! Mismatches found." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=========================================================================" -ForegroundColor Green
Write-Host "   [SUCCESS] SIMULATION AND 100% VERIFICATION COMPLETED SUCCESSFULLY!    " -ForegroundColor Green
Write-Host "=========================================================================" -ForegroundColor Green
