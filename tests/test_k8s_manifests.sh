#!/usr/bin/env bash
# ==============================================================================
# Kubernetes Manifest & Policy Test Suite
# ==============================================================================
# Bu test betiği, Kustomize ile üretilen Kubernetes manifestlerinin
# doğruluğunu, yapısını ve güvenlik politikalarına uyumunu otomatik doğrular.
# ==============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED_TESTS=0
FAILED_TESTS=0

assert_test() {
  local test_name="$1"
  local status="$2"
  if [ "$status" -eq 0 ]; then
    echo -e "${GREEN}[PASS]${NC} $test_name"
    PASSED_TESTS=$((PASSED_TESTS + 1))
  else
    echo -e "${RED}[FAIL]${NC} $test_name"
    FAILED_TESTS=$((FAILED_TESTS + 1))
  fi
}

echo "=========================================================="
echo " 🧪 Kubernetes Manifest & Policy Testleri Başlatılıyor..."
echo "=========================================================="

# 1. Kustomize Render Testleri
echo -e "\n--- 1. Kustomize Render Testleri ---"

kubectl kustomize k8s/base > /dev/null 2>&1
assert_test "Kustomize Base Render Başarılı" $?

kubectl kustomize k8s/overlays/dev > /dev/null 2>&1
assert_test "Kustomize Overlay Dev Render Başarılı" $?

kubectl kustomize k8s/overlays/prod > /dev/null 2>&1
assert_test "Kustomize Overlay Prod Render Başarılı" $?

# Manifest içeriklerini değişkenlere al
PROD_MANIFEST=$(kubectl kustomize k8s/overlays/prod)
BASE_MANIFEST=$(kubectl kustomize k8s/base)

# 2. Güvenlik ve Mimari Politika Testleri
echo -e "\n--- 2. Mimari ve Güvenlik Politika Testleri ---"

# Test: App Deployment Prod Replicas = 2
echo "$PROD_MANIFEST" | grep -A 5 "name: app-deployment" | grep -q "replicas: 2"
assert_test "Production App Deployment Replicas Eşittir 2" $?

# Test: phpMyAdmin Prod Replicas = 0 (Güvenlik Kısıtlaması)
echo "$PROD_MANIFEST" | grep -A 5 "name: pma-deployment" | grep -q "replicas: 0"
assert_test "Production phpMyAdmin Replicas Eşittir 0 (Devre Dışı)" $?

# Test: Nginx ve PHP-FPM Readiness Probe
echo "$BASE_MANIFEST" | grep -q "readinessProbe:"
assert_test "App Container ReadinessProbe Tanımlı" $?

# Test: Nginx ve PHP-FPM Liveness Probe
echo "$BASE_MANIFEST" | grep -q "livenessProbe:"
assert_test "App Container LivenessProbe Tanımlı" $?

# Test: Resource Requests & Limits Tanımlı
echo "$BASE_MANIFEST" | grep -q "resources:" && echo "$BASE_MANIFEST" | grep -q "limits:"
assert_test "Konteyner Kaynak İstek ve Sınırları (Requests/Limits) Tanımlı" $?

# Test: allowPrivilegeEscalation: false Kontrolü
echo "$BASE_MANIFEST" | grep -q "allowPrivilegeEscalation: false"
assert_test "SecurityContext (allowPrivilegeEscalation: false) Tanımlı" $?

# Test: MySQL Startup Probe
echo "$BASE_MANIFEST" | grep -q "startupProbe:"
assert_test "MySQL StartupProbe Tanımlı" $?

# Test: Production Ingress SSL / TLS Tanımı
echo "$PROD_MANIFEST" | grep -q "secretName: app-tls-cert"
assert_test "Production Ingress TLS Sertifikası (app-tls-cert) Tanımlı" $?

# Test: cert-manager ClusterIssuer Annotation
echo "$PROD_MANIFEST" | grep -q "cert-manager.io/cluster-issuer: letsencrypt-prod"
assert_test "Production Ingress cert-manager Annotation Tanımlı" $?

echo -e "\n=========================================================="
echo -e " 📊 TEST SONUÇLARI: ${GREEN}${PASSED_TESTS} Başarılı${NC} | ${RED}${FAILED_TESTS} Hatalı${NC}"
echo "=========================================================="

if [ "$FAILED_TESTS" -ne 0 ]; then
  exit 1
fi
