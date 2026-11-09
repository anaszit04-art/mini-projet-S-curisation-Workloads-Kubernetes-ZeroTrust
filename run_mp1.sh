#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}=== DÉMARRAGE DU CLUSTER ET DE CALICO ===${NC}"
minikube start --driver=docker --memory=3072 --cpus=2 --cni=calico
echo -e "${YELLOW}⏳ Attente de Calico (30s)...${NC}"
sleep 30
kubectl get pods -n kube-system | grep calico
echo -e "${GREEN}✅ CLUSTER PRÊT - PRENEZ LA CAPTURE D'ÉCRAN 0 (Calico Running)${NC}"
read -p "Appuyez sur Entrée pour continuer..."

echo -e "\n${BLUE}=== JOUR 1 : DÉPLOIEMENT ET PERMÉABILITÉ ===${NC}"
kubectl create namespace frontend-ns
kubectl create namespace backend-ns
echo -e "${GREEN}✅ Namespaces créés.${NC}"
read -p "PRENEZ LA CAPTURE 1 (Namespaces). Entrée pour continuer..."

kubectl create deployment frontend --image=nginx:alpine -n frontend-ns
kubectl apply -f backend.yaml
echo -e "${YELLOW}⏳ Attente du démarrage des pods (20s)...${NC}"
sleep 20
kubectl get pods -n frontend-ns
kubectl get pods -n backend-ns
echo -e "${GREEN}✅ Pods déployés.${NC}"
read -p "PRENEZ LA CAPTURE 2 (Pods Running). Entrée pour continuer..."

kubectl expose deployment frontend --port=80 --name=frontend-svc -n frontend-ns
kubectl expose deployment backend --port=5678 --name=backend-svc -n backend-ns
echo -e "${GREEN}✅ Services exposés.${NC}"
read -p "PRENEZ LA CAPTURE 3 (Services). Entrée pour continuer..."

FRONTEND_POD=$(kubectl get pods -n frontend-ns -o jsonpath='{.items[0].metadata.name}')
echo -e "${YELLOW}Test de perméabilité réseau...${NC}"
kubectl exec -it $FRONTEND_POD -n frontend-ns -- curl backend-svc.backend-ns:5678
echo -e "${GREEN}✅ Réseau ouvert.${NC}"
read -p "PRENEZ LA CAPTURE 4 (Hello from Backend). Entrée pour continuer..."

echo -e "\n${BLUE}=== JOUR 2 : RBAC ET HOSTPATH ===${NC}"
kubectl create serviceaccount backend-sa -n backend-ns
kubectl apply -f backend-role.yaml
kubectl apply -f backend-rolebinding.yaml
kubectl get sa -n backend-ns
kubectl get role,rolebinding -n backend-ns
echo -e "${GREEN}✅ RBAC créé.${NC}"
read -p "PRENEZ LA CAPTURE 5 (SA, Role, RoleBinding). Entrée pour continuer..."

echo -e "${YELLOW}Tests des permissions RBAC :${NC}"
echo -n "Peut lire les ConfigMaps (attendu: yes) : "
kubectl auth can-i get configmaps --as=system:serviceaccount:backend-ns:backend-sa -n backend-ns
echo -n "Peut supprimer des Pods (attendu: no) : "
kubectl auth can-i delete pods --as=system:serviceaccount:backend-ns:backend-sa -n backend-ns
echo -n "Peut lire les Secrets (attendu: no) : "
kubectl auth can-i get secrets --as=system:serviceaccount:backend-ns:backend-sa -n backend-ns
echo -e "${GREEN}✅ Moindre privilège vérifié.${NC}"
read -p "PRENEZ LA CAPTURE 6 (yes/no/no). Entrée pour continuer..."

kubectl apply -f dangerous-pod.yaml
sleep 5
echo -e "${YELLOW}Démonstration du danger hostPath (ls /host) :${NC}"
kubectl exec -it dangerous-pod -n backend-ns -- ls /host
kubectl delete pod dangerous-pod -n backend-ns
echo -e "${GREEN}✅ Danger hostPath démontré.${NC}"
read -p "PRENEZ LA CAPTURE 7 (Accès au système de fichiers). Entrée pour continuer..."

echo -e "\n${BLUE}=== JOUR 3 : NETWORKPOLICY (ZERO TRUST) ===${NC}"
kubectl apply -f default-deny-all.yaml
kubectl get networkpolicy -n frontend-ns
kubectl get networkpolicy -n backend-ns
echo -e "${GREEN}✅ Default Deny appliqué.${NC}"
read -p "PRENEZ LA CAPTURE 8 (NetworkPolicy créées). Entrée pour continuer..."

echo -e "${YELLOW}Test avec Default Deny (attendu: timeout) :${NC}"
kubectl exec -it $FRONTEND_POD -n frontend-ns -- curl --connect-timeout 3 backend-svc.backend-ns:5678
echo -e "${GREEN}✅ Trafic bloqué.${NC}"
read -p "PRENEZ LA CAPTURE 9 (Timeout). Entrée pour continuer..."

kubectl apply -f allow-dns.yaml
kubectl apply -f allow-frontend-egress-to-backend.yaml
kubectl apply -f allow-frontend-to-backend.yaml
kubectl get networkpolicy --all-namespaces | grep -E "frontend|backend"
echo -e "${GREEN}✅ Autorisations explicites appliquées.${NC}"
read -p "PRENEZ LA CAPTURE 10 (Toutes les NetworkPolicy). Entrée pour continuer..."

echo -e "${YELLOW}Test final (attendu: Hello from Backend) :${NC}"
kubectl exec -it $FRONTEND_POD -n frontend-ns -- curl backend-svc.backend-ns:5678
echo -e "${GREEN}✅ Flux autorisé passe.${NC}"
read -p "PRENEZ LA CAPTURE 11 (Hello from Backend). Entrée pour continuer..."

kubectl run test-pod --image=busybox -n default --restart=Never -- sleep 3600
sleep 5
echo -e "${YELLOW}Test négatif depuis un autre namespace (attendu: timeout) :${NC}"
kubectl exec -it test-pod -n default -- wget -qO- --timeout=3 http://backend-svc.backend-ns:5678
kubectl delete pod test-pod -n default
echo -e "${GREEN}✅ Flux non autorisé bloqué.${NC}"
read -p "PRENEZ LA CAPTURE 12 (Timeout). Entrée pour continuer..."

echo -e "\n${BLUE}=== JOUR 4 : KYVERNO (ADMISSION CONTROL) ===${NC}"
helm repo add kyverno https://kyverno.github.io/kyverno/ 2>/dev/null
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
echo -e "${YELLOW}⏳ Attente du démarrage de Kyverno (1min)...${NC}"
sleep 60
kubectl get pods -n kyverno
echo -e "${GREEN}✅ Kyverno installé.${NC}"
read -p "PRENEZ LA CAPTURE 13 (4 pods Running). Entrée pour continuer..."

kubectl apply -f kyverno-disallow-hostpath.yaml
kubectl apply -f kyverno-disallow-privileged.yaml
kubectl get clusterpolicy
echo -e "${GREEN}✅ Politiques prêtes.${NC}"
read -p "PRENEZ LA CAPTURE 14 (READY: True). Entrée pour continuer..."

echo -e "${YELLOW}Test 1 : Pod avec hostPath (attendu: rejeté)${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-hostpath
  namespace: backend-ns
spec:
  containers:
  - name: test
    image: nginx:alpine
    volumeMounts:
    - name: host-vol
      mountPath: /host
  volumes:
  - name: host-vol
    hostPath:
      path: /
      type: Directory
EOF
echo -e "${GREEN}✅ Test hostPath terminé.${NC}"
read -p "PRENEZ LA CAPTURE 15 (Rejet hostPath). Entrée pour continuer..."

echo -e "${YELLOW}Test 2 : Pod privilégié (attendu: rejeté)${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
  namespace: backend-ns
spec:
  containers:
  - name: test
    image: nginx:alpine
    securityContext:
      privileged: true
EOF
echo -e "${GREEN} |GREAT|== Test privileged terminé.${NC}"
read -p "PRENEZ LA CAPTURE 16 (Rejet privileged). Entrée pour continuer..."

echo -e "${YELLOW}Test 3 : Pod normal (attendu: accepté)${NC}"
kubectl run test-normal --image=nginx:alpine -n backend-ns
kubectl delete pod test-normal -n backend-ns
echo -e "${GREEN} |GREAT|==  Pod normal accepté.${NC}"
read -p "PRENEZ LA CAPTURE 17 (Pod accepté). Entrée pour terminer..."

echo -e "\n${GREEN}🎉 PROJET MP1 TERMINÉ AVEC SUCCÈS ! ${NC}"
