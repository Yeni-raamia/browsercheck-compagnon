# browsercheck-compagnon
# Phase 1 - Briques 1 a 3 : detection, lecture de configuration, controles

$baseLocale = $env:LOCALAPPDATA

$navigateurs = @(
    @{
        Nom        = "Google Chrome"
        Profil     = Join-Path $baseLocale "Google\Chrome\User Data"
        CheminsExe = @(
            "C:\Program Files\Google\Chrome\Application\chrome.exe"
            "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
            (Join-Path $baseLocale "Google\Chrome\Application\chrome.exe")
        )
    },
    @{
        Nom        = "Microsoft Edge"
        Profil     = Join-Path $baseLocale "Microsoft\Edge\User Data"
        CheminsExe = @(
            "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
            "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
        )
    }
)

# ===== LES CONTROLES =====

function Test-SafeBrowsing {
    param($config)

    if ($config.safebrowsing.enhanced -eq $true) {
        return @{
            Controle = "Navigation securisee (Safe Browsing)"
            Etat     = "Bon"
            Detail   = "Protection renforcee activee."
        }
    }
    elseif ($config.safebrowsing.enabled -eq $false) {
        return @{
            Controle = "Navigation securisee (Safe Browsing)"
            Etat     = "A risque"
            Detail   = "La protection est desactivee."
        }
    }
    else {
        return @{
            Controle = "Navigation securisee (Safe Browsing)"
            Etat     = "Bon"
            Detail   = "Protection standard active."
        }
    }
}

function Test-PasswordManager {
    param($config)

    if ($config.credentials_enable_service -eq $false) {
        return @{
            Controle = "Gestionnaire de mots de passe du navigateur"
            Etat     = "Bon"
            Detail   = "Le navigateur n'enregistre pas les mots de passe."
        }
    }
    else {
        return @{
            Controle = "Gestionnaire de mots de passe du navigateur"
            Etat     = "A ameliorer"
            Detail   = "Le navigateur peut enregistrer les mots de passe ; un gestionnaire dedie est plus sur."
        }
    }
}

function Test-HttpsOnly {
    param($config)

    if ($config.https_only_mode_enabled -eq $true) {
        return @{
            Controle = "Connexions securisees (mode HTTPS)"
            Etat     = "Bon"
            Detail   = "Le mode HTTPS strict est active."
        }
    }
    else {
        return @{
            Controle = "Connexions securisees (mode HTTPS)"
            Etat     = "A ameliorer"
            Detail   = "Le mode HTTPS strict n'est pas active."
        }
    }
}

function Test-SearchEngine {
    param($config)

    if ($null -ne $config.default_search_provider_data) {
        return @{
            Controle = "Moteur de recherche par defaut"
            Etat     = "A ameliorer"
            Detail   = "Le moteur a ete defini par une extension ou une strategie - a verifier."
        }
    }
    else {
        return @{
            Controle = "Moteur de recherche par defaut"
            Etat     = "Bon"
            Detail   = "Moteur de recherche d'origine, non modifie."
        }
    }
}

function Test-Extensions {
    param($config)

    $nombre = 0
    if ($null -ne $config.extensions.settings) {
        $nombre = ($config.extensions.settings.PSObject.Properties.Name).Count
    }

    if ($nombre -eq 0) {
        return @{
            Controle = "Extensions installees"
            Etat     = "Bon"
            Detail   = "Aucune extension installee : surface d'attaque nulle."
        }
    }
    else {
        return @{
            Controle = "Extensions installees"
            Etat     = "A ameliorer"
            Detail   = "$nombre extension(s) installee(s) - a passer en revue."
        }
    }
}

function Test-SitePermissions {
    param($config)

    $exceptions = $config.profile.content_settings.exceptions
    $categories = @("geolocation", "media_stream_camera", "media_stream_mic")

    $total = 0
    foreach ($cat in $categories) {
        if ($null -ne $exceptions.$cat) {
            $total += ($exceptions.$cat.PSObject.Properties.Name).Count
        }
    }

    if ($total -eq 0) {
        return @{
            Controle = "Permissions sensibles accordees aux sites"
            Etat     = "Bon"
            Detail   = "Aucun site n'a acces a la camera, au micro ou a la localisation."
        }
    }
    else {
        return @{
            Controle = "Permissions sensibles accordees aux sites"
            Etat     = "A ameliorer"
            Detail   = "$total autorisation(s) sensible(s) accordee(s) - a passer en revue."
        }
    }
}

function Test-BrowserVersion {
    param($cheminsExe)

    # On cherche le premier chemin d'executable qui existe reellement.
    $exe = $null
    foreach ($chemin in $cheminsExe) {
        if (Test-Path $chemin) {
            $exe = $chemin
            break
        }
    }

    if ($null -eq $exe) {
        return @{
            Controle = "Mise a jour du navigateur"
            Etat     = "A ameliorer"
            Detail   = "Version non determinee : executable introuvable."
        }
    }

    # On lit les informations du fichier executable.
    $infos   = Get-Item -Path $exe
    $version = $infos.VersionInfo.ProductVersion
    $jours   = (New-TimeSpan -Start $infos.LastWriteTime -End (Get-Date)).Days

    if ($jours -le 45) {
        return @{
            Controle = "Mise a jour du navigateur"
            Etat     = "Bon"
            Detail   = "Version $version, mise a jour il y a $jours jour(s)."
        }
    }
    else {
        return @{
            Controle = "Mise a jour du navigateur"
            Etat     = "A ameliorer"
            Detail   = "Version $version, pas de mise a jour depuis $jours jours - verifier la mise a jour automatique."
        }
    }
}

function Get-Score {
    param($resultats)

    $points = 0
    foreach ($r in $resultats) {
        switch ($r.Etat) {
            "Bon"         { $points += 2 }
            "A ameliorer" { $points += 1 }
            "A risque"    { $points += 0 }
        }
    }

    $maximum = $resultats.Count * 2
    return [math]::Round(($points / $maximum) * 100)
}

# ===== PROGRAMME PRINCIPAL =====

foreach ($nav in $navigateurs) {

    if (Test-Path $nav.Profil) {
        Write-Host "[OK] $($nav.Nom) est installe."

        $cheminConfig = Join-Path $nav.Profil "Default\Preferences"

        if (Test-Path $cheminConfig) {
            try {
                $config = ConvertFrom-Json -InputObject (Get-Content -Path $cheminConfig -Raw)

                # On lance les controles et on rassemble leurs resultats.
                $resultats = @()
                $resultats += Test-SafeBrowsing    -config $config
                $resultats += Test-PasswordManager -config $config
                $resultats += Test-HttpsOnly       -config $config
                $resultats += Test-SearchEngine    -config $config
                $resultats += Test-Extensions      -config $config
                $resultats += Test-SitePermissions -config $config
                $resultats += Test-BrowserVersion  -cheminsExe $nav.CheminsExe

               # Affichage des controles.
                foreach ($r in $resultats) {
                    Write-Host "     [$($r.Etat)] $($r.Controle) : $($r.Detail)"
                }

                # Calcul et affichage du score.
                $score = Get-Score -resultats $resultats
                Write-Host ""
                Write-Host "     >>> Niveau de protection : $score %"
            }
            catch {
                Write-Host "     /!\ La configuration n'a pas pu etre lue."
            }
        }
        else {
            Write-Host "     /!\ Aucun fichier de configuration trouve."
        }
    }
    else {
        Write-Host "[--] $($nav.Nom) n'a pas ete detecte sur cette machine."
    }
}