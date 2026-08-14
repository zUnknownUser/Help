function Import-LocalEnvironment {
    param([string]$ApiDirectory)

    $environmentFile = Join-Path $ApiDirectory '.env.local'
    if (-not (Test-Path -LiteralPath $environmentFile)) {
        throw "Crie $environmentFile a partir de .env.example."
    }

    Get-Content -LiteralPath $environmentFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $separator = $line.IndexOf('=')
            if ($separator -lt 1) { throw 'Linha inválida em .env.local.' }
            [Environment]::SetEnvironmentVariable(
                $line.Substring(0, $separator).Trim(),
                $line.Substring($separator + 1).Trim(),
                'Process'
            )
        }
    }
}
