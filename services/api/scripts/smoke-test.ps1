$ErrorActionPreference = 'Stop'

$apiDirectory = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'import-env.ps1')
Import-LocalEnvironment -ApiDirectory $apiDirectory

Push-Location $apiDirectory
try {
    docker compose up -d --build api
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $healthy = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        try {
            $response = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/health' -TimeoutSec 1
            if ($response.status -eq 'ok') {
                $healthy = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    }
    if (-not $healthy) {
        docker compose logs api
        throw 'API não respondeu ao health check.'
    }
    Write-Output 'LOCAL_API_HEALTH=ok'

    $readiness = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/ready' -TimeoutSec 3
    if ($readiness.status -ne 'ready') {
        throw 'PostgreSQL não respondeu ao readiness check.'
    }
    Write-Output 'POSTGRES_READINESS=ready'

    $homeResponse = Invoke-RestMethod -Uri 'http://127.0.0.1:8080/v1/home' -TimeoutSec 3
    if (
        $homeResponse.data.categories.Count -ne 8 -or
        $homeResponse.data.recommended_services.Count -ne 3 -or
        $homeResponse.data.promotions.Count -ne 3 -or
        $homeResponse.data.benefits.Count -gt 4
    ) {
        throw 'GET /v1/home retornou um contrato incompleto.'
    }
    Write-Output 'POSTGRES_HOME_AGGREGATE=ok'

    $unknownEmail = "integration-$([guid]::NewGuid().ToString('N'))@example.invalid"
    $resetResponse = Invoke-WebRequest `
        -Method Post `
        -Uri 'http://127.0.0.1:8080/v1/auth/password-reset' `
        -ContentType 'application/json' `
        -Body (@{ email = $unknownEmail } | ConvertTo-Json -Compress) `
        -UseBasicParsing
    if ($resetResponse.StatusCode -ne 202) {
        throw "Recuperação retornou HTTP $($resetResponse.StatusCode)."
    }
    Write-Output 'FIREBASE_PASSWORD_RESET_UNKNOWN_USER=accepted'
}
finally {
    Pop-Location
}
