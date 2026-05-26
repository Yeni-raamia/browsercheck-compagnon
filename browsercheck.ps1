# browsercheck-compagnon
# Phase 1 - Briques 1 & 2 : detection des navigateurs et lecture de leur configuration

$baseLocale = $env:LOCALAPPDATA

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

foreach ($nav in $navigateurs) {

    if (Test-Path $nav.Profil) {
        Write-Host "[OK] $($nav.Nom) est installe."

        # On construit le chemin du fichier de configuration "Preferences",
        # situe dans le profil "Default" du navigateur.
        $cheminConfig = Join-Path $nav.Profil "Default\Preferences"

        if (Test-Path $cheminConfig) {
            try {
                # On lit tout le fichier d'un bloc, puis on transforme
                # le texte JSON en un objet explorable par PowerShell.
                $texteJson = Get-Content -Path $cheminConfig -Raw
                $config    = ConvertFrom-Json -InputObject $texteJson

                Write-Host "     Configuration lue et analysee avec succes."
            }
            catch {
                Write-Host "     /!\ La configuration existe mais n'a pas pu etre lue."
            }
        }
        else {
            Write-Host "     /!\ Aucun fichier de configuration trouve (profil Default)."
        }
    }
    else {
        Write-Host "[--] $($nav.Nom) n'a pas ete detecte sur cette machine."
    }
}