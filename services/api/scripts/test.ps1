$ErrorActionPreference = 'Stop'

$apiDirectory = Split-Path -Parent $PSScriptRoot
$temporaryDirectory = Join-Path $apiDirectory '.tmp'
$cacheDirectory = Join-Path $apiDirectory '.gocache'

New-Item -ItemType Directory -Force -Path $temporaryDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $cacheDirectory | Out-Null

$env:GOTMPDIR = $temporaryDirectory
$env:GOCACHE = $cacheDirectory

Push-Location $apiDirectory
try {
    go test ./internal/domain/auth ./internal/application/auth ./internal/application/home ./internal/adapters/mailersend ./internal/adapters/firebaseauth ./internal/healthcheck -count=1
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $httpTestBinary = Join-Path $temporaryDirectory 'api_http_tests.exe'
    go test -c -o $httpTestBinary ./internal/adapters/httpapi
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $httpTestBinary
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $configTestBinary = Join-Path $temporaryDirectory 'api_config_tests.exe'
    go test -c -o $configTestBinary ./internal/config
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & $configTestBinary
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}
