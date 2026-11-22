$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')
node scripts/backup-postgres.mjs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
