# browsercheck-compagnon
# Phase 2 - durcissement interactif

# ===== RELANCE AUTOMATIQUE EN ADMINISTRATEUR (Phase 2) =====
# Pour corriger des reglages, le script doit ecrire dans une zone
# protegee de Windows, ce qui exige les droits administrateur.
# Ce bloc s'execute en premier : si le script n'est pas lance en
# administrateur, il se relance lui-meme en version elevee.

$estAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $estAdmin) {
    Write-Host "Droits administrateur requis. Relance du script en cours..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "[OK] Droits administrateur confirmes." -ForegroundColor Green

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
    param($config, $navigateur)

    # Fiche de correction : indique a Set-Strategie quoi ecrire.
    # Elle depend du navigateur. Chrome se corrige via la strategie
    # SafeBrowsingProtectionLevel ; Edge utilise un autre mecanisme
    # (SmartScreen), qu'on traitera plus tard.
   if ($navigateur -eq "Google Chrome") {
        $correction = @{
            Chemin = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
            Nom    = 'SafeBrowsingProtectionLevel'
            Valeur = 1
            Type   = 'DWord'
        }
    }
    elseif ($navigateur -eq "Microsoft Edge") {
        $correction = @{
            Chemin = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
            Nom    = 'SmartScreenEnabled'
            Valeur = 1
            Type   = 'DWord'
        }
    }
    elseif ($navigateur -eq "Microsoft Edge") {
        $correction = @{
            Chemin = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
            Nom    = 'PasswordManagerEnabled'
            Valeur = 0
            Type   = 'DWord'
        }
    }
    else {
        $correction = $null
    }

    if ($config.safebrowsing.enhanced -eq $true) {
        return @{
            Controle   = "Navigation sécurisée (Safe Browsing)"
            Etat       = "Bon"
            Detail     = "Protection renforcée activée."
            Risque     = ""
            Conseil    = ""
            Items      = @()
            Correction = $null
        }
    }
    elseif ($config.safebrowsing.enabled -eq $false) {
        return @{
            Controle   = "Navigation sécurisée (Safe Browsing)"
            Etat       = "À risque"
            Detail     = "La protection est désactivée."
            Risque     = "Le navigateur ne vous avertit plus avant les sites de hameçonnage ni les téléchargements malveillants connus."
            Conseil    = "Réactivez la protection dans Paramètres > Confidentialité et sécurité > Sécurité."
            Items      = @()
            Correction = $correction
        }
    }
    else {
        return @{
            Controle   = "Navigation sécurisée (Safe Browsing)"
            Etat       = "Bon"
            Detail     = "Protection standard active."
            Risque     = ""
            Conseil    = ""
            Items      = @()
            Correction = $null
        }
    }
}

function Test-PasswordManager {
    param($config, $navigateur)

    # Fiche de correction. Chrome bloque l'enregistrement des mots de
    # passe via la strategie PasswordManagerEnabled (0 = desactive).
    # Edge utilise une strategie distincte : a traiter plus tard.
    if ($navigateur -eq "Google Chrome") {
        $correction = @{
            Chemin = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
            Nom    = 'PasswordManagerEnabled'
            Valeur = 0
            Type   = 'DWord'
        }
    }
    else {
        $correction = $null
    }

    if ($config.credentials_enable_service -eq $false) {
        return @{
            Controle   = "Gestionnaire de mots de passe du navigateur"
            Etat       = "Bon"
            Detail     = "Le navigateur n'enregistre pas les mots de passe."
            Risque     = ""
            Conseil    = ""
            Items      = @()
            Correction = $null
        }
    }
    else {
        return @{
            Controle   = "Gestionnaire de mots de passe du navigateur"
            Etat       = "À améliorer"
            Detail     = "Le navigateur est autorisé à enregistrer les mots de passe."
            Risque     = "Les mots de passe stockés dans le navigateur sont accessibles à toute personne qui ouvre votre session Windows."
            Conseil    = "Utilisez un gestionnaire dédié (Bitwarden, KeePass) et désactivez l'enregistrement dans le navigateur."
            Items      = @()
            Correction = $correction
        }
    }
}

function Test-HttpsOnly {
    param($config, $navigateur)

    # Fiche de correction. Chrome force le mode HTTPS via la strategie
    # HttpsOnlyMode, avec la valeur texte "force_enabled" (mode strict).
    # Edge utilise une autre strategie : a traiter plus tard.
    if ($navigateur -eq "Google Chrome") {
        $correction = @{
            Chemin = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
            Nom    = 'HttpsOnlyMode'
            Valeur = 'force_enabled'
            Type   = 'String'
        }
    }
    elseif ($navigateur -eq "Microsoft Edge") {
        $correction = @{
            Chemin = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
            Nom    = 'HttpsOnlyMode'
            Valeur = 'force_enabled'
            Type   = 'String'
        }
    }
    else {
        $correction = $null
    }

    if ($config.https_only_mode_enabled -eq $true) {
        return @{
            Controle   = "Connexions sécurisées (mode HTTPS)"
            Etat       = "Bon"
            Detail     = "Le mode HTTPS strict est activé."
            Risque     = ""
            Conseil    = ""
            Items      = @()
            Correction = $null
        }
    }
    else {
        return @{
            Controle   = "Connexions sécurisées (mode HTTPS)"
            Etat       = "À améliorer"
            Detail     = "Le mode HTTPS strict n'est pas activé."
            Risque     = "Le navigateur peut charger des pages en HTTP non chiffré, où vos données circulent en clair et peuvent être interceptées sur le réseau."
            Conseil    = "Activez « Toujours utiliser des connexions sécurisées » dans les paramètres de confidentialité."
            Items      = @()
            Correction = $correction
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

# ===== LES CORRECTIONS (Phase 2) =====
# Set-Strategie : pose une stratégie de navigateur dans le registre.
# Toutes les corrections de la Phase 2 s'appuieront sur cette fonction.

function Set-Strategie {
    param(
        [string]$Chemin,   # chemin de la cle de strategie dans le registre
        [string]$Nom,      # nom de la valeur a ecrire
        $Valeur,           # valeur a ecrire
        [string]$Type      # type attendu : 'DWord' (un nombre) ou 'String' (du texte)
    )

    try {
        # Creer la cle de strategie si elle n'existe pas encore.
        if (-not (Test-Path $Chemin)) {
            New-Item -Path $Chemin -Force | Out-Null
        }

        # Ecrire la valeur (la creer, ou la mettre a jour si elle existe deja).
        New-ItemProperty -Path $Chemin -Name $Nom -Value $Valeur -PropertyType $Type -Force | Out-Null

        Write-Host "     [Applique] $Nom = $Valeur" -ForegroundColor Green
        return $true
    }
    catch {
        # En cas de probleme, on previent sans faire planter tout le script.
        Write-Host "     [Echec] Impossible d'appliquer $Nom : $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ===== LE RAPPORT HTML (fonction reutilisable) =====
# Construit le rapport, l'enregistre et l'ouvre. Le parametre
# $correctionsAppliquees (vide ou rempli) sert a marquer "Corrige"
# les controles repares pendant l'execution.

function New-RapportHtml {
    param($rapportNavigateurs, $correctionsAppliquees, $apresCorrection)

    $dateRapport = Get-Date -Format "dd/MM/yyyy 'à' HH:mm"
    $ordreEtat = @{ "À risque" = 0; "À améliorer" = 1; "Bon" = 2 }

    # Banniere d'instruction en haut du rapport, adaptee a la phase.
    if ($apresCorrection) {
        if ($correctionsAppliquees.Count -gt 0) {
            $banniereClasse = "banniere-final"
            $banniereTexte  = "$($correctionsAppliquees.Count) correction(s) ont été appliquées. Elles prendront pleinement effet au prochain démarrage du navigateur. Pour annuler une correction, suivez les commandes affichées dans la fenêtre PowerShell."
        }
        else {
            $banniereClasse = "banniere-diagnostic"
            $banniereTexte  = "Aucune correction n'a été appliquée. Vous pouvez relancer l'outil à tout moment."
        }
    }
    else {
        $banniereClasse = "banniere-diagnostic"
        $banniereTexte  = "Ce rapport liste les points à renforcer sur vos navigateurs. Cliquez sur « Ce que vous risquez » et « À faire » pour en savoir plus sur chaque point. Pour appliquer les corrections, retournez à la fenêtre PowerShell ouverte derrière : l'outil vous demandera votre accord avant chaque modification — rien ne sera changé sans votre « oui »."
    }

    $corps = "        <div class='grille'>`n"

    foreach ($navResultat in $rapportNavigateurs) {

        # Score recalcule : un controle corrige vaut 2 points (comme un "Bon").
        $points = 0
        foreach ($r in $navResultat.Resultats) {
            $estCorrige = $false
            foreach ($c in $correctionsAppliquees) {
                if ($c.Navigateur -eq $navResultat.Nom -and $c.Controle -eq $r.Controle) {
                    $estCorrige = $true
                }
            }
            if ($estCorrige) {
                $points += 2
            }
            else {
                switch ($r.Etat) {
                    "Bon"         { $points += 2 }
                    "À améliorer" { $points += 1 }
                    "À risque"    { $points += 0 }
                }
            }
        }
        $maximum = $navResultat.Resultats.Count * 2
        $scoreAffiche = [math]::Round(($points / $maximum) * 100)

        if     ($scoreAffiche -ge 80) { $classeScore = "score-bon" }
        elseif ($scoreAffiche -ge 50) { $classeScore = "score-moyen" }
        else                          { $classeScore = "score-faible" }

        $corps += "          <section class='panneau'>`n"
        $corps += "            <h2>$($navResultat.Nom)</h2>`n"
        $corps += "            <div class='score-ligne'>`n"
        $corps += "              <div class='jauge'><div class='jauge-remplissage $classeScore' style='width: $scoreAffiche%'></div></div>`n"
        $corps += "              <span class='score-valeur $($classeScore)-texte'>$scoreAffiche %</span>`n"
        $corps += "            </div>`n"

        $controlesTries = $navResultat.Resultats | Sort-Object { $ordreEtat[$_.Etat] }

        foreach ($r in $controlesTries) {

            $estCorrige = $false
            foreach ($c in $correctionsAppliquees) {
                if ($c.Navigateur -eq $navResultat.Nom -and $c.Controle -eq $r.Controle) {
                    $estCorrige = $true
                }
            }

            if ($estCorrige) {

                # Controle corrige : carte distincte (vert emeraude + coche).
                $corps += "            <div class='controle etat-corrige'>`n"
                $corps += "              <div class='controle-tete'>`n"
                $corps += "                <span class='controle-nom'>$($r.Controle)</span>`n"
                $corps += "                <span class='etat'>&#10003; Corrigé</span>`n"
                $corps += "              </div>`n"
                $corps += "              <div class='controle-detail'>Corrigé par browsercheck-compagnon. Effectif au prochain démarrage du navigateur.</div>`n"
                $corps += "            </div>`n"
            }
            elseif ($r.Etat -eq "Bon") {

                $corps += "            <div class='controle etat-bon'>`n"
                $corps += "              <div class='controle-tete'>`n"
                $corps += "                <span class='controle-nom'>$($r.Controle)</span>`n"
                $corps += "                <span class='etat'>$($r.Etat)</span>`n"
                $corps += "              </div>`n"
                $corps += "              <div class='controle-detail'>$($r.Detail)</div>`n"
                $corps += "            </div>`n"
            }
            else {

                switch ($r.Etat) {
                    "À améliorer" { $classeEtat = "etat-ameliorer" }
                    "À risque"    { $classeEtat = "etat-risque" }
                    default       { $classeEtat = "" }
                }

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

                # Risque et conseil deplies a la demande (accordeons).
                $corps += "              <details class='accordeon'>`n"
                $corps += "                <summary class='etiquette etiquette-risque'>Ce que vous risquez</summary>`n"
                $corps += "                <p class='bloc-texte'>$($r.Risque)</p>`n"
                $corps += "              </details>`n"
                $corps += "              <details class='accordeon'>`n"
                $corps += "                <summary class='etiquette etiquette-conseil'>À faire</summary>`n"
                $corps += "                <p class='bloc-texte'>$($r.Conseil)</p>`n"
                $corps += "              </details>`n"

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
        <div class="banniere $banniereClasse"><p>$banniereTexte</p></div>
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
                $resultats += Test-SafeBrowsing    -config $config -navigateur $nav.Nom
                $resultats += Test-PasswordManager -config $config -navigateur $nav.Nom
                $resultats += Test-HttpsOnly       -config $config -navigateur $nav.Nom
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

# ===== RAPPORT DE DIAGNOSTIC (Phase 2) =====
New-RapportHtml -rapportNavigateurs $rapportNavigateurs -correctionsAppliquees @() -apresCorrection $false
# On ouvre le rapport pour que l'utilisateur prenne connaissance des
# points a renforcer avant de decider s'il veut securiser ou non.

Write-Host ""
Write-Host "[i] Ouverture du rapport de diagnostic..."
New-RapportHtml -rapportNavigateurs $rapportNavigateurs -correctionsAppliquees @()

Write-Host "Lisez le rapport, puis revenez ici pour la suite." -ForegroundColor Cyan

# ===== CORRECTION INTERACTIVE (Phase 2) =====
# Apres lecture du rapport : question maitresse, puis controle par controle.
# Regle d'or : rien n'est modifie sans un "oui" explicite de l'utilisateur.

$correctionsAppliquees = @()

# Combien de points sont corrigeables automatiquement ?
$corrigeablesCount = 0
foreach ($navResultat in $rapportNavigateurs) {
    foreach ($r in $navResultat.Resultats) {
        if ($r.Etat -ne "Bon" -and $null -ne $r.Correction) {
            $corrigeablesCount++
        }
    }
}

Write-Host ""
Write-Host "===== Securiser votre navigateur ====="

if ($corrigeablesCount -eq 0) {
    Write-Host "Aucun point ne peut etre corrige automatiquement."
}
else {
    Write-Host "$corrigeablesCount point(s) peuvent etre corriges automatiquement."
    $reponseSecuriser = Read-Host "Souhaitez-vous lancer la securisation de votre navigateur ? (O/N)"

    if ($reponseSecuriser -eq "O") {

        foreach ($navResultat in $rapportNavigateurs) {
            foreach ($r in $navResultat.Resultats) {

                if ($r.Etat -ne "Bon" -and $null -ne $r.Correction) {

                    Write-Host ""
                    Write-Host "[$($navResultat.Nom)] $($r.Controle)" -ForegroundColor Yellow
                    Write-Host "  Constat : $($r.Detail)"
                    Write-Host "  Risque  : $($r.Risque)"
                    Write-Host "  Note    : apres correction, ce reglage sera 'gere par votre organisation'."

                    $reponse = Read-Host "  Appliquer la correction ? (O/N)"

                    if ($reponse -eq "O") {
                        $succes = Set-Strategie -Chemin $r.Correction.Chemin -Nom $r.Correction.Nom -Valeur $r.Correction.Valeur -Type $r.Correction.Type
                        if ($succes) {
                            $correctionsAppliquees += @{
                                Navigateur = $navResultat.Nom
                                Controle   = $r.Controle
                                Chemin     = $r.Correction.Chemin
                                Nom        = $r.Correction.Nom
                            }
                        }
                    }
                    else {
                        Write-Host "     [Ignore] Aucune modification effectuee." -ForegroundColor DarkGray
                    }
                }
            }
        }
    }
    else {
        Write-Host "Securisation annulee. Aucune modification apportee."
    }
}

# ===== RECAPITULATIF DES CORRECTIONS (Phase 2) =====
Write-Host ""
Write-Host "===== Recapitulatif des corrections ====="

if ($correctionsAppliquees.Count -eq 0) {
    Write-Host "Aucune correction appliquee."
}
else {
    Write-Host "$($correctionsAppliquees.Count) correction(s) appliquee(s) :"
    foreach ($c in $correctionsAppliquees) {
        Write-Host ""
        Write-Host "  [$($c.Navigateur)] $($c.Controle)" -ForegroundColor Green
        Write-Host "    Pour annuler : Remove-ItemProperty -Path '$($c.Chemin)' -Name '$($c.Nom)'"
    }
    Write-Host ""
    Write-Host "Ces commandes sont a executer dans un PowerShell administrateur."
}

# ===== RAPPORT FINAL (Phase 2 - avec les corrections appliquees) =====
# Le meme rapport, mais avec les controles repares marques "Corrige".
New-RapportHtml -rapportNavigateurs $rapportNavigateurs -correctionsAppliquees $correctionsAppliquees
New-RapportHtml -rapportNavigateurs $rapportNavigateurs -correctionsAppliquees $correctionsAppliquees -apresCorrection $true