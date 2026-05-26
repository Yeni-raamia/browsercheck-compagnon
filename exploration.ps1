# exploration.ps1 - derniere sonde : le moteur de recherche par defaut
$cheminConfig = Join-Path $env:LOCALAPPDATA "Google\Chrome\User Data\Default\Preferences"
$config = ConvertFrom-Json -InputObject (Get-Content -Path $cheminConfig -Raw)

Write-Host "===== MOTEUR DE RECHERCHE PAR DEFAUT ====="
$config.default_search_provider | ConvertTo-Json -Depth 4