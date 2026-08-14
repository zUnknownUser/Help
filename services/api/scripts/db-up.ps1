$ErrorActionPreference = 'Stop'

$apiDirectory = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'import-env.ps1')
Import-LocalEnvironment -ApiDirectory $apiDirectory

Push-Location $apiDirectory
try {
    docker compose up -d db
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        docker compose exec -T db pg_isready -U help -d help *> $null
        if ($LASTEXITCODE -eq 0) {
            $ready = $true
            break
        }
        Start-Sleep -Milliseconds 500
    }
    if (-not $ready) { throw 'PostgreSQL não ficou disponível a tempo.' }

    go run ./cmd/migrate
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}
