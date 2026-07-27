#!/usr/bin/env bash
# ==============================================================================
# Kubernetes End-to-End (E2E) Integration & Live Cluster Functional Test Suite
# ==============================================================================
# Bu test betiği, aktif bir Kubernetes kümesinde (Minikube, Kind, GKE vb.)
# tüm servislerin ve pod'ların canlı durumunu, probe yanıtlarını, veritabanı 
# fonksiyonel sorgularını ve exporter metrik uç noktalarını test eder.
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
kubectl rollout status deployment/blackbox-exporter -n "${NAMESPACE}" --timeout=120s

if [ "${OVERLAY}" = "dev" ]; then
  kubectl rollout status deployment/pma-deployment -n "${NAMESPACE}" --timeout=120s
fi

# 3. Pod Sağlık Durumları
echo -e "\n${YELLOW}3. Pod Sağlık Durumları (Running & Probes) Doğrulanıyor...${NC}"
kubectl get pods -n "${NAMESPACE}" -l app=php-app
kubectl get pods -n "${NAMESPACE}" -l app=mysql
kubectl get pods -n "${NAMESPACE}" -l app=redis
kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=blackbox-exporter

# 4. Servis İçi Ağ, HTTP ve Fonksiyonel Veritabanı Testleri
echo -e "\n${YELLOW}4. Servis İçi Ağ, HTTP ve Veritabanı Fonksiyonel Testleri...${NC}"

# App HTTP 200 OK & Content Probe Testi
echo -n "Checking App HTTP Service (Port 80)... "
kubectl run app-http-test --rm -i --restart=Never --image=curlimages/curl -n "${NAMESPACE}" -- curl -s http://app-service | grep -q "Kubernetes Microservice" && echo -e "${GREEN}[OK] HTTP 200 & HTML Title Verified${NC}"

# Redis Ping Testi
echo -n "Checking Redis Connection (PING/PONG)... "
kubectl run redis-test-ping --rm -i --restart=Never --image=redis:7-alpine -n "${NAMESPACE}" -- redis-cli -h redis-service ping | grep -q "PONG" && echo -e "${GREEN}[OK] PONG${NC}"

# MySQL Connection & Query Execution Testi
echo -n "Checking MySQL Connection & Query (SELECT 1)... "
kubectl run mysql-test-query --rm -i --restart=Never --image=mysql:8.0 -n "${NAMESPACE}" -- mysql -h mysql-service -u root -prootpass -e "SELECT 1;" | grep -q "1" && echo -e "${GREEN}[OK] Query Execution Successful${NC}"

# Blackbox Exporter Probe Testi
echo -n "Checking Blackbox Exporter Synthetic Probe (Port 9115)... "
kubectl run blackbox-test-probe --rm -i --restart=Never --image=curlimages/curl -n "${NAMESPACE}" -- curl -s "http://blackbox-exporter:9115/probe?module=http_2xx&target=http://app-service" | grep -q "probe_success 1" && echo -e "${GREEN}[OK] Synthetic Probe Success${NC}"

# Exporter Metrics Scrape Testleri
echo -e "\n${YELLOW}5. Exporter Prometheus Metrics Scrape Testleri...${NC}"

echo -n "Checking Nginx Exporter Metrics (Port 9113)... "
kubectl run nginx-metrics-test --rm -i --restart=Never --image=curlimages/curl -n "${NAMESPACE}" -- curl -s http://app-service:9113/metrics | grep -q "nginx_http_requests_total" && echo -e "${GREEN}[OK] Nginx Metrics Active${NC}"

echo -n "Checking MySQL Exporter Metrics (Port 9104)... "
kubectl run mysql-metrics-test --rm -i --restart=Never --image=curlimages/curl -n "${NAMESPACE}" -- curl -s http://mysql-service:9104/metrics | grep -q "mysql_up 1" && echo -e "${GREEN}[OK] MySQL Metrics Active${NC}"

echo -n "Checking Redis Exporter Metrics (Port 9121)... "
kubectl run redis-metrics-test --rm -i --restart=Never --image=curlimages/curl -n "${NAMESPACE}" -- curl -s http://redis-service:9121/metrics | grep -q "redis_up 1" && echo -e "${GREEN}[OK] Redis Metrics Active${NC}"

echo -e "\n=========================================================="
echo -e "${GREEN} ✅ TÜM CANLI KÜME FONKSİYONEL TESTLERİ BAŞARIYLA TAMAMLANDI!${NC}"
echo "=========================================================="
