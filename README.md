# Mini-projet 1 - DevSecOps : Sécurisation des workloads Kubernetes

Ce dépôt contient l'implémentation du Mini-projet 1 (approche Zero Trust).

## Structure du projet
- `backend.yaml` : Déploiement du backend avec ServiceAccount
- `backend-role.yaml` / `backend-rolebinding.yaml` : Configuration RBAC
- `default-deny-all.yaml` : Politique réseau par défaut
- `allow-dns.yaml` / `allow-frontend-*.yaml` : Autorisations réseau
- `kyverno-disallow-*.yaml` : Politiques d'admission

## Technologies utilisées
- Minikube (driver Docker)
- Calico (CNI)
- Kyverno (Admission Controller)
- Helm

## Auteur
Anas ZITOUNI et Anas EL BAOUCHI
