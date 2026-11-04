@echo off
chcp 65001 >nul
title Launch ModelSim GUI - Elevator Controller

cd /d "%~dp0"

echo =========================================================================
echo   Dang khoi dong ModelSim GUI voi Waveform truc quan...
echo =========================================================================

start "" vsim -do run_gui.do
