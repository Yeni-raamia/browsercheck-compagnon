# browsercheck-compagnon

> Diagnostic de sécurité des navigateurs web, pour Windows.
> Un outil de la famille **Compagnon**.

`browsercheck-compagnon` analyse la configuration de sécurité des navigateurs installés sur un poste Windows et produit un rapport clair, visuel et actionnable — lisible aussi bien par un utilisateur que par un responsable de la sécurité.

![Aperçu du rapport browsercheck-compagnon](apercu-rapport.png)

## À propos

Cet outil fait partie des **Outils Compagnon**, une famille d'outils de cybersécurité pensés pour être simples, lisibles et utiles au quotidien.

**Version actuelle : Phase 1 — diagnostic.** L'outil analyse et rend compte ; il ne modifie aucun réglage. Il fonctionne en **lecture seule**, ne demande **aucun droit administrateur**, et ne transmet **aucune donnée** sur internet : il lit uniquement des fichiers locaux.

## Ce que l'outil vérifie

Pour chaque navigateur détecté — Google Chrome et Microsoft Edge — sept contrôles de sécurité :

- **Navigation sécurisée** — la protection contre les sites de hameçonnage
- **Gestionnaire de mots de passe** — l'enregistrement des mots de passe par le navigateur
- **Connexions sécurisées** — l'activation du mode HTTPS strict
- **Moteur de recherche par défaut** — sa modification éventuelle par une extension
- **Extensions installées** — leur présence et leur nombre
- **Permissions sensibles** — les sites ayant accès à la caméra, au micro ou à la localisation
- **Mise à jour du navigateur** — l'ancienneté de la version installée

Chaque navigateur reçoit un **score de protection**. Pour chaque point à corriger, le rapport précise le risque encouru et l'action recommandée.

## Le rapport

À la fin de l'analyse, l'outil génère et ouvre `rapport.html` : un tableau de bord présentant les navigateurs côte à côte, chacun avec son score, ses points conformes et ses points à corriger mis en avant. Le rapport est **autonome** — il s'ouvre sans connexion internet, polices et mascotte comprises.

## Prérequis

- Windows 10 ou 11
- Windows PowerShell 5.1 (inclus dans Windows) ou PowerShell 7 et supérieur

## Utilisation

Récupérez le dépôt :

```
git clone https://github.com/Yeni-raamia/browsercheck-compagnon.git
```

Si l'exécution de scripts est bloquée sur votre poste, autorisez-la pour votre compte — à faire une seule fois :

```
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

Placez-vous dans le dossier de l'outil et lancez l'analyse :

```
.\browsercheck.ps1
```

L'analyse dure quelques secondes, puis le rapport `rapport.html` s'ouvre automatiquement.

## Contenu du dépôt

- `browsercheck.ps1` — le script d'analyse
- `rapport.css` — la feuille de style du rapport (charte Outils Compagnon ; polices et mascotte intégrées)

Le fichier `rapport.html` est généré localement à chaque exécution.

## Feuille de route

- **Phase 2 — durcissement interactif** : proposer de corriger directement les réglages signalés par le diagnostic.

## Crédits

Les polices **Baloo 2** et **Nunito** sont incluses sous licence SIL Open Font License.

## Auteur

**Yeni DOUKAKAS**

- LinkedIn : https://www.linkedin.com/in/yeni-doukakas-b9682a127/
- Contact : cybercompagnon@gmail.com

## Licence

Ce projet est distribué sous licence MIT — voir le fichier `LICENSE`.
