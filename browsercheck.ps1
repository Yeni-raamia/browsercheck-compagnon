# browsercheck-compagnon
# Phase 1 - Brique 1 : detection des navigateurs installes

# Dossier ou Windows range les donnees applicatives locales de l'utilisateur courant.
$baseLocale = $env:LOCALAPPDATA

# Liste des navigateurs a examiner : pour chacun, son nom et le chemin
# de son dossier de configuration "User Data".
$navigateurs = @(
    @{
        Nom    = "Google Chrome"
        Profil = Join-Path $baseLocale "Google\Chrome\User Data"
    },
    @{
        Nom    = "Microsoft Edge"
        Profil = Join-Path $baseLocale "Microsoft\Edge\User Data"
    }
)

# Pour chaque navigateur de la liste, on verifie si son dossier existe.
foreach ($nav in $navigateurs) {

    if (Test-Path $nav.Profil) {
        Write-Host "[OK] $($nav.Nom) est installe."
        Write-Host "     Configuration : $($nav.Profil)"
    }
    else {
        Write-Host "[--] $($nav.Nom) n'a pas ete detecte sur cette machine."
    }
}