$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
    $agentPython = Join-Path $PSScriptRoot '.venv/Scripts/python.exe'
    if (!(Test-Path -LiteralPath $agentPython)) { throw 'Create this project environment first: python -m venv .venv' }
    & $agentPython backend/run.py
} finally { Pop-Location }
