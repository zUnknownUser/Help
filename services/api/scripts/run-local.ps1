$ErrorActionPreference = 'Stop'

$apiDirectory = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'import-env.ps1')
Import-LocalEnvironment -ApiDirectory $apiDirectory

Push-Location $apiDirectory
try {
    go run ./cmd/api
}
finally {
    Pop-Location
}
