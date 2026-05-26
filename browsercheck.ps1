# browsercheck-compagnon
# Phase 1 - Briques 1 a 3 : detection, lecture de configuration, controles

# On indique a la console d'afficher correctement les accents.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

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
            Controle = "Navigation sécurisée (Safe Browsing)"
            Etat     = "Bon"
            Detail   = "Protection renforcée activée."
        }
    }
    elseif ($config.safebrowsing.enabled -eq $false) {
        return @{
            Controle = "Navigation sécurisée (Safe Browsing)"
            Etat     = "À risque"
            Detail   = "La protection est désactivée."
        }
    }
    else {
        return @{
            Controle = "Navigation sécurisée (Safe Browsing)"
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
            Etat     = "À améliorer"
            Detail   = "Le navigateur peut enregistrer les mots de passe ; un gestionnaire dédié est plus sûr."
        }
    }
}

function Test-HttpsOnly {
    param($config)

    if ($config.https_only_mode_enabled -eq $true) {
        return @{
            Controle = "Connexions sécurisées (mode HTTPS)"
            Etat     = "Bon"
            Detail   = "Le mode HTTPS strict est activé."
        }
    }
    else {
        return @{
            Controle = "Connexions sécurisées (mode HTTPS)"
            Etat     = "À améliorer"
            Detail   = "Le mode HTTPS strict n'est pas activé."
        }
    }
}

function Test-SearchEngine {
    param($config)

    if ($null -ne $config.default_search_provider_data) {
        return @{
            Controle = "Moteur de recherche par défaut"
            Etat     = "À améliorer"
            Detail   = "Le moteur a été défini par une extension ou une stratégie - à vérifier."
        }
    }
    else {
        return @{
            Controle = "Moteur de recherche par défaut"
            Etat     = "Bon"
            Detail   = "Moteur de recherche d'origine, non modifié."
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
            Controle = "Extensions installées"
            Etat     = "Bon"
            Detail   = "Aucune extension installée : surface d'attaque nulle."
        }
    }
    else {
        return @{
            Controle = "Extensions installées"
            Etat     = "À améliorer"
            Detail   = "$nombre extension(s) installée(s) - à passer en revue."
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
            Controle = "Permissions sensibles accordées aux sites"
            Etat     = "Bon"
            Detail   = "Aucun site n'a accès à la caméra, au micro ou à la localisation."
        }
    }
    else {
        return @{
            Controle = "Permissions sensibles accordées aux sites"
            Etat     = "À améliorer"
            Detail   = "$total autorisation(s) sensible(s) accordée(s) - à passer en revue."
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
            Controle = "Mise à jour du navigateur"
            Etat     = "À améliorer"
            Detail   = "Version non déterminée : exécutable introuvable."
        }
    }

    # On lit les informations du fichier executable.
    $infos   = Get-Item -Path $exe
    $version = $infos.VersionInfo.ProductVersion
    $jours   = (New-TimeSpan -Start $infos.LastWriteTime -End (Get-Date)).Days

    if ($jours -le 45) {
        return @{
            Controle = "Mise à jour du navigateur"
            Etat     = "Bon"
            Detail   = "Version $version, mise à jour il y a $jours jour(s)."
        }
    }
    else {
        return @{
            Controle = "Mise à jour du navigateur"
            Etat     = "À améliorer"
            Detail   = "Version $version, pas de mise à jour depuis $jours jours - vérifier la mise à jour automatique."
        }
    }
}

function Get-Score {
    param($resultats)

    $points = 0
    foreach ($r in $resultats) {
        switch ($r.Etat) {
            "Bon"         { $points += 2 }
            "À améliorer" { $points += 1 }
            "À risque"    { $points += 0 }
        }
    }

    $maximum = $resultats.Count * 2
    return [math]::Round(($points / $maximum) * 100)
}

# ===== PROGRAMME PRINCIPAL =====

# On prepare une liste vide : elle recevra les resultats de chaque
# navigateur, pour construire le rapport HTML apres la boucle.
$rapportNavigateurs = @()

foreach ($nav in $navigateurs) {

    if (Test-Path $nav.Profil) {
        Write-Host "[OK] $($nav.Nom) est installé."

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

                # On range les resultats de ce navigateur dans la liste,
                # pour le rapport HTML.
                $rapportNavigateurs += @{
                    Nom       = $nav.Nom
                    Score     = $score
                    Resultats = $resultats
                }
            }
            catch {
                Write-Host "     /!\ La configuration n'a pas pu être lue."
            }
        }
        else {
            Write-Host "     /!\ Aucun fichier de configuration trouvé."
        }
    }
    else {
        Write-Host "[--] $($nav.Nom) n'a pas été détecté sur cette machine."
    }
}

Write-Host ""
Write-Host "[i] Résultats collectés pour $($rapportNavigateurs.Count) navigateur(s)."

# ===== GENERATION DU RAPPORT =====

# Date et heure de generation, pour le pied de page.
$dateRapport = Get-Date -Format "dd/MM/yyyy 'à' HH:mm"

# On construit le corps du rapport : un panneau par navigateur,
# disposes en tableau de bord.
$corps = "        <div class='grille'>`n"

foreach ($navResultat in $rapportNavigateurs) {

    # Couleur de la jauge selon le niveau du score.
    if     ($navResultat.Score -ge 80) { $classeScore = "score-bon" }
    elseif ($navResultat.Score -ge 50) { $classeScore = "score-moyen" }
    else                               { $classeScore = "score-faible" }

    $corps += "          <section class='panneau'>`n"
    $corps += "            <h2>$($navResultat.Nom)</h2>`n"
    $corps += "            <div class='score-ligne'>`n"
    $corps += "              <div class='jauge'><div class='jauge-remplissage $classeScore' style='width: $($navResultat.Score)%'></div></div>`n"
    $corps += "              <span class='score-valeur $($classeScore)-texte'>$($navResultat.Score) %</span>`n"
    $corps += "            </div>`n"

    foreach ($r in $navResultat.Resultats) {

        # On choisit une classe de couleur selon l'etat du controle.
        switch ($r.Etat) {
            "Bon"         { $classeEtat = "etat-bon" }
            "À améliorer" { $classeEtat = "etat-ameliorer" }
            "À risque"    { $classeEtat = "etat-risque" }
            default       { $classeEtat = "" }
        }

        $corps += "            <div class='controle $classeEtat'>`n"
        $corps += "              <div class='controle-tete'>`n"
        $corps += "                <span class='controle-nom'>$($r.Controle)</span>`n"
        $corps += "                <span class='etat'>$($r.Etat)</span>`n"
        $corps += "              </div>`n"
        $corps += "              <div class='controle-detail'>$($r.Detail)</div>`n"
        $corps += "            </div>`n"
    }

    $corps += "          </section>`n"
}

$corps += "        </div>`n"

$html = @"
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>browsercheck-compagnon</title>
    <link rel="stylesheet" href="rapport.css">
</head>
<body>
    <div class="page">
        <header>
            <div class="mascotte" role="img" aria-label="Mascotte browsercheck-compagnon"></div>
            <div class="header-texte">
                <h1>browsercheck-compagnon</h1>
                <p>Diagnostic de sécurité de vos navigateurs</p>
            </div>
        </header>
$corps
        <footer>
            <p>Rapport généré le $dateRapport</p>
            <p>browsercheck-compagnon &mdash; par Yeni DOUKAKAS</p>
        </footer>
    </div>
</body>
</html>
"@

$cheminRapport = Join-Path $PSScriptRoot "rapport.html"
Set-Content -Path $cheminRapport -Value $html -Encoding UTF8
Invoke-Item $cheminRapport