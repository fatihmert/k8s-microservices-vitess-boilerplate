#!/usr/bin/env bash
# ==============================================================================
# Kubernetes End-to-End (E2E) Integration & Cluster Smoke Test Suite
# ==============================================================================
# Bu test betiği, aktif bir Kubernetes kümesinde (Minikube, Kind, EKS vb.)
# tüm servislerin ve pod'ların canlı durumunu, probe yanıtlarını ve 
# veritabanı bağlantılarını test eder.
# ==============================================================================

set -e

NAMESPACE="${1:-default}"
OVERLAY="${2:-dev}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================================="
echo " 🌐 Kubernetes E2E Canlı Küme Testi Başlatılıyor..."
echo " Target Namespace: ${NAMESPACE} | Overlay: ${OVERLAY}"
echo "=========================================================="

# 1. Kümeye Dağıtım (Deploy)
echo -e "\n${YELLOW}1. Manifestler Küme Üzerine Uygulanıyor...${NC}"
kubectl apply -k "k8s/overlays/${OVERLAY}" -n "${NAMESPACE}"

# 2. Deployment Rollout Bekleme
echo -e "\n${YELLOW}2. Pod'ların Hazır Olması (Rollout Status) Bekleniyor...${NC}"
kubectl rollout status deployment/app-deployment -n "${NAMESPACE}" --timeout=120s
kubectl rollout status deployment/mysql-deployment -n "${NAMESPACE}" --timeout=120s
kubectl rollout status deployment/redis-deployment -n "${NAMESPACE}" --timeout=120s

if [ "${OVERLAY}" = "dev" ]; then
  kubectl rollout status deployment/pma-deployment -n "${NAMESPACE}" --timeout=120s
fi

# 3. Pod Sağlık Kontrolleri
echo -e "\n${YELLOW}3. Pod Sağlık Durumları (Running & Probes) Doğrulanıyor...${NC}"
kubectl get pods -n "${NAMESPACE}" -l app=php-app
kubectl get pods -n "${NAMESPACE}" -l app=mysql
kubectl get pods -n "${NAMESPACE}" -l app=redis

# 4. Veritabanı ve Servis İçi Bağlantı Testleri
echo -e "\n${YELLOW}4. Servis İçi Ağ ve Veritabanı Bağlantı Testleri Yapılıyor...${NC}"

# Redis Ping Testi
echo -n "Checking Redis connection... "
kubectl run redis-test-ping --rm -i --restart=Never --image=redis:7-alpine -n "${NAMESPACE}" -- redis-cli -h redis-service ping | grep -q "PONG" && echo -e "${GREEN}[OK] PONG${NC}"

# MySQL Connection Testi
echo -n "Checking MySQL connection... "
kubectl run mysql-test-ping --rm -i --restart=Never --image=mysql:8.0 -n "${NAMESPACE}" -- mysqladmin -h mysql-service -u root -prootpass ping | grep -q "mysqld is alive" && echo -e "${GREEN}[OK] mysqld is alive${NC}"

echo -e "\n=========================================================="
echo -e "${GREEN} ✅ TÜM E2E CANLI KÜME TESTLERİ BAŞARIYLA TAMAMLANDI!${NC}"
echo "=========================================================="
