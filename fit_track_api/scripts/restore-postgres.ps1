$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
if (-not $args[0]) {
  Write-Error 'Uso: .\scripts\restore-postgres.ps1 <ruta-al-dump.dump>'
}
node scripts/restore-postgres.mjs @args
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
