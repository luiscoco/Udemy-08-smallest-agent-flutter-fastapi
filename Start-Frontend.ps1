param([string]$FlutterPath = 'flutter')
$ErrorActionPreference = 'Stop'
if (!$PSBoundParameters.ContainsKey('FlutterPath') -and !(Get-Command $FlutterPath -ErrorAction SilentlyContinue)) {
    $temporaryFlutter = Join-Path $env:TEMP 'codex-flutter-sdk\bin\flutter.bat'
    if (Test-Path -LiteralPath $temporaryFlutter -PathType Leaf) {
        $FlutterPath = $temporaryFlutter
        Write-Host "Using Flutter SDK: $FlutterPath"
    }
}
Push-Location (Join-Path $PSScriptRoot 'frontend')
try {
    if (!(Get-Command $FlutterPath -ErrorAction SilentlyContinue)) { throw 'Install Flutter stable and reopen Windows Terminal, or pass -FlutterPath with the path to flutter.bat. See README.md.' }
    & $FlutterPath pub get
    if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency installation failed.' }
    & $FlutterPath run -d web-server --web-hostname 127.0.0.1 --web-port 4900 --dart-define=API_BASE_URL=http://127.0.0.1:8300
} finally { Pop-Location }
