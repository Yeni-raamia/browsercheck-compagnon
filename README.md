# browsercheck-compagnon

**Un compagnon qui veille sur la sécurité de votre navigateur.**

browsercheck-compagnon examine les navigateurs installés sur une machine, en évalue la sécurité, et présente le résultat dans un rapport clair et bienveillant. L'esprit de l'outil : accompagner plutôt qu'effrayer. Pas de jargon, pas de culpabilisation — un état des lieux compréhensible, et des pistes concrètes pour s'améliorer.

## Statut

**Projet en développement.** Ce dépôt est un chantier. Les fonctionnalités décrites ci-dessous sont en cours de construction.

## Ce que fait l'outil — Phase 1 : le diagnostic

La première version analyse **Google Chrome et Microsoft Edge**, en lecture seule — elle ne modifie rien — et vérifie sept points :

- La mise à jour du navigateur
- L'activation de la navigation sécurisée (Safe Browsing)
- L'inventaire des extensions installées
- Le forçage des connexions sécurisées (HTTPS)
- La légitimité du moteur de recherche par défaut
- Les permissions sensibles accordées aux sites (caméra, micro, localisation)
- Le stockage de mots de passe dans le navigateur

Le résultat est présenté dans un **rapport HTML** : un niveau de protection global, puis, pour chaque point, son état, une explication en langage simple, et ce qu'il faudrait faire.

## La suite — Phase 2 : le durcissement

Une phase ultérieure permettra d'appliquer les corrections directement depuis le rapport, de façon transparente et réversible.

---

Un outil de la famille **Compagnon**, écrit par **Yeni DOUKAKAS** — RSSI · Threat hunting · Forensique numérique.
Profil : [github.com/Yeni-raamia](https://github.com/Yeni-raamia)