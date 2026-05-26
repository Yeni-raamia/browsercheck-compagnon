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
# Chaque controle renvoie : Controle, Etat, Detail (le constat),
# Risque (ce que l'utilisateur risque), Conseil (quoi faire),
# Items (la liste des elements concernes, quand il y en a une).

function Test-SafeBrowsing {
    param($config)

    if ($config.safebrowsing.enhanced -eq $true) {
        return @{
            Controle = "Navigation sécurisée (Safe Browsing)"
            Etat     = "Bon"
            Detail   = "Protection renforcée activée."
            Risque   = ""
            Conseil  = ""
            Items    = @()
        }
    }
    elseif ($config.safebrowsing.enabled -eq $false) {
        return @{
            Controle = "Navigation sécurisée (Safe Browsing)"
            Etat     = "À risque"
            Detail   = "La protection est désactivée."
            Risque   = "Le navigateur ne vous avertit plus avant les sites de hameçonnage ni les téléchargements malveillants connus."
            Conseil  = "Réactivez la protection dans Paramètres > Confidentialité et sécurité > Sécurité."
            Items    = @()
        }
    }
    else {
        return @{
            Controle = "Navigation sécurisée (Safe Browsing)"
            Etat     = "Bon"
            Detail   = "Protection standard active."
            Risque   = ""
            Conseil  = ""
            Items    = @()
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
            Risque   = ""
            Conseil  = ""
            Items    = @()
        }
    }
    else {
        return @{
            Controle = "Gestionnaire de mots de passe du navigateur"
            Etat     = "À améliorer"
            Detail   = "Le navigateur est autorisé à enregistrer les mots de passe."
            Risque   = "Les mots de passe stockés dans le navigateur sont accessibles à toute personne qui ouvre votre session Windows."
            Conseil  = "Utilisez un gestionnaire dédié (Bitwarden, KeePass) et désactivez l'enregistrement dans le navigateur."
            Items    = @()
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
            Risque   = ""
            Conseil  = ""
            Items    = @()
        }
    }
    else {
        return @{
            Controle = "Connexions sécurisées (mode HTTPS)"
            Etat     = "À améliorer"
            Detail   = "Le mode HTTPS strict n'est pas activé."
            Risque   = "Le navigateur peut charger des pages en HTTP non chiffré, où vos données circulent en clair et peuvent être interceptées sur le réseau."
            Conseil  = "Activez « Toujours utiliser des connexions sécurisées » dans les paramètres de confidentialité."
            Items    = @()
        }
    }
}

function Test-SearchEngine {
    param($config)

    if ($null -ne $config.default_search_provider_data) {
        return @{
            Controle = "Moteur de recherche par défaut"
            Etat     = "À améliorer"
            Detail   = "Le moteur de recherche a été défini par une extension ou une stratégie."
            Risque   = "Un moteur imposé peut rediriger vos recherches, y insérer de la publicité ou enregistrer tout ce que vous cherchez."
            Conseil  = "Vérifiez le moteur par défaut et l'extension qui l'a modifié, puis rétablissez un moteur de confiance."
            Items    = @()
        }
    }
    else {
        return @{
            Controle = "Moteur de recherche par défaut"
            Etat     = "Bon"
            Detail   = "Moteur de recherche d'origine, non modifié."
            Risque   = ""
            Conseil  = ""
            Items    = @()
        }
    }
}

function Test-Extensions {
    param($config)

    # On releve les extensions et, si possible, leur nom lisible.
    $noms = @()
    if ($null -ne $config.extensions.settings) {
        foreach ($id in $config.extensions.settings.PSObject.Properties.Name) {
            $ext = $config.extensions.settings.$id
            if ($null -ne $ext.manifest.name) {
                $noms += $ext.manifest.name
            }
            else {
                $noms += $id
            }
        }
    }

    if ($noms.Count -eq 0) {
        return @{
            Controle = "Extensions installées"
            Etat     = "Bon"
            Detail   = "Aucune extension installée : surface d'attaque nulle."
            Risque   = ""
            Conseil  = ""
            Items    = @()
        }
    }
    else {
        return @{
            Controle = "Extensions installées"
            Etat     = "À améliorer"
            Detail   = "$($noms.Count) extension(s) présente(s) sur ce navigateur."
            Risque   = "Chaque extension peut lire et modifier les pages que vous consultez ; une seule extension compromise suffit à exposer votre navigation."
            Conseil  = "Passez en revue la liste ci-dessous et supprimez les extensions que vous n'utilisez pas ou ne reconnaissez pas."
            Items    = $noms
        }
    }
}

function Test-SitePermissions {
    param($config)

    $exceptions = $config.profile.content_settings.exceptions

    # Categorie technique -> libelle lisible.
    $categories = @{
        geolocation         = "localisation"
        media_stream_camera = "caméra"
        media_stream_mic    = "micro"
    }

    # On regroupe par site : chaque site -> la liste de ses permissions.
    $parSite = @{}
    foreach ($cle in $categories.Keys) {
        if ($null -ne $exceptions.$cle) {
            foreach ($motif in $exceptions.$cle.PSObject.Properties.Name) {
                # Le motif ressemble a "https://exemple.com:443,*" : on isole le site.
                $site = $motif.Split(',')[0] -replace '^https?://', '' -replace ':\d+$', ''
                if (-not $parSite.ContainsKey($site)) {
                    $parSite[$site] = @()
                }
                $parSite[$site] += $categories[$cle]
            }
        }
    }

    if ($parSite.Count -eq 0) {
        return @{
            Controle = "Permissions sensibles accordées aux sites"
            Etat     = "Bon"
            Detail   = "Aucun site n'a accès à la caméra, au micro ou à la localisation."
            Risque   = ""
            Conseil  = ""
            Items    = @()
        }
    }

    # Mise en forme : "exemple.com (caméra, micro)"
    $liste = @()
    foreach ($site in $parSite.Keys) {
        $perms = ($parSite[$site] | Select-Object -Unique) -join ", "
        $liste += "$site ($perms)"
    }

    return @{
        Controle = "Permissions sensibles accordées aux sites"
        Etat     = "À améliorer"
        Detail   = "$($parSite.Count) site(s) ont accès à des fonctions sensibles de votre appareil."
        Risque   = "Un site auquel vous avez accordé la caméra, le micro ou la localisation conserve cet accès. S'il est compromis, il peut s'en servir à votre insu."
        Conseil  = "Ouvrez Paramètres > Confidentialité et sécurité > Paramètres des sites, et retirez les accès devenus inutiles."
        Items    = $liste
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
            Risque   = "Sans pouvoir vérifier la version, impossible de garantir que le navigateur reçoit les correctifs de sécurité."
            Conseil  = "Vérifiez manuellement la version du navigateur et lancez une recherche de mises à jour."
            Items    = @()
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
            Risque   = ""
            Conseil  = ""
            Items    = @()
        }
    }
    else {
        return @{
            Controle = "Mise à jour du navigateur"
            Etat     = "À améliorer"
            Detail   = "Version $version, dernière mise à jour il y a $jours jours."
            Risque   = "Un navigateur qui n'est pas à jour conserve des failles déjà connues et activement exploitées."
            Conseil  = "Lancez une recherche de mises à jour, redémarrez le navigateur et activez la mise à jour automatique."
            Items    = @()
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

# Ordre d'affichage des controles : les problemes d'abord.
$ordreEtat = @{ "À risque" = 0; "À améliorer" = 1; "Bon" = 2 }

# On construit le corps du rapport : un panneau par navigateur.
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

    # On classe les controles : ceux a corriger en premier.
    $controlesTries = $navResultat.Resultats | Sort-Object { $ordreEtat[$_.Etat] }

    foreach ($r in $controlesTries) {

        switch ($r.Etat) {
            "Bon"         { $classeEtat = "etat-bon" }
            "À améliorer" { $classeEtat = "etat-ameliorer" }
            "À risque"    { $classeEtat = "etat-risque" }
            default       { $classeEtat = "" }
        }

        if ($r.Etat -eq "Bon") {

            # Controle conforme : ligne compacte.
            $corps += "            <div class='controle $classeEtat'>`n"
            $corps += "              <div class='controle-tete'>`n"
            $corps += "                <span class='controle-nom'>$($r.Controle)</span>`n"
            $corps += "                <span class='etat'>$($r.Etat)</span>`n"
            $corps += "              </div>`n"
            $corps += "              <div class='controle-detail'>$($r.Detail)</div>`n"
            $corps += "            </div>`n"
        }
        else {

            # Controle a corriger : carte detaillee.
            $corps += "            <div class='controle controle-alerte $classeEtat'>`n"
            $corps += "              <div class='controle-tete'>`n"
            $corps += "                <span class='controle-nom'>$($r.Controle)</span>`n"
            $corps += "                <span class='etat'>$($r.Etat)</span>`n"
            $corps += "              </div>`n"
            $corps += "              <div class='controle-detail'>$($r.Detail)</div>`n"

            if ($r.Items.Count -gt 0) {
                $corps += "              <ul class='controle-items'>`n"
                foreach ($item in $r.Items) {
                    $corps += "                <li>$item</li>`n"
                }
                $corps += "              </ul>`n"
            }

            $corps += "              <p class='etiquette etiquette-risque'>Ce que vous risquez</p>`n"
            $corps += "              <p class='bloc-texte'>$($r.Risque)</p>`n"
            $corps += "              <p class='etiquette etiquette-conseil'>À faire</p>`n"
            $corps += "              <p class='bloc-texte'>$($r.Conseil)</p>`n"
            $corps += "            </div>`n"
        }
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