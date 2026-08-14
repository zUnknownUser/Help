$ErrorActionPreference = 'Stop'

$apiDirectory = Split-Path -Parent $PSScriptRoot
$databaseName = 'help_chat_test_' + ([guid]::NewGuid().ToString('N'))
$databaseURL = "postgres://help:help_local_only@db:5432/${databaseName}?sslmode=disable"

Push-Location $apiDirectory
try {
    docker compose exec -T db createdb -U help $databaseName
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    docker run --rm `
        --network api_default `
        -e "DATABASE_URL=$databaseURL" `
        -e "CHAT_TEST_DATABASE_URL=$databaseURL" `
        -v "${apiDirectory}:/src" `
        -w /src `
        golang:1.26.6-alpine `
        sh -c 'go run ./cmd/migrate && go test ./internal/adapters/httpapi -run TestRealtimeTwoClients -count=1 && go test ./internal/adapters/httpapi -run TestChatRepository -count=1'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    docker compose exec -T db dropdb -U help --if-exists $databaseName
    Pop-Location
}
