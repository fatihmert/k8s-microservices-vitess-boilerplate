#!/usr/bin/env python3
# ==============================================================================
# Kubernetes Structure & Policy Deep Validator (Pure Python Stdlib)
# ==============================================================================
# Bu betik, PyYAML bağımlılığı olmaksızın Kustomize çıktısını nesne yapısı,
# probe'lar, güvenlik kuralları ve kaynak sınırları seviyesinde doğrular.
# ==============================================================================

import sys
import subprocess
import re

def get_kustomize_manifest(target_dir):
    try:
        cmd = ["kubectl", "kustomize", target_dir]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return result.stdout
    except Exception as e:
        print(f"❌ Kustomize derleme hatası ({target_dir}): {e}")
        sys.exit(1)

def split_yaml_docs(yaml_str):
    raw_docs = yaml_str.split("---")
    docs = []
    for d in raw_docs:
        d = d.strip()
        if d:
            docs.append(d)
    return docs

def validate_base_structure():
    print("--- 1. Base Katmanı Yapısal Veri Nesnesi Testleri ---")
    base_raw = get_kustomize_manifest("k8s/base")
    docs = split_yaml_docs(base_raw)
    
    passed = 0
    total = 0

    # 1. Kind Kontrolleri
    expected_kinds = ["Deployment", "Service", "Secret", "PersistentVolumeClaim", 
                      "ServiceMonitor", "PodMonitor", "PrometheusRule", "AlertmanagerConfig", "Probe"]
    
    found_kinds = set(re.findall(r"^kind:\s+(\w+)", base_raw, re.MULTILINE))
    
    for k in expected_kinds:
        total += 1
        if k in found_kinds:
            print(f"  [PASS] Kubernetes Nesne Türü ({k}) Mevcut")
            passed += 1
        else:
            print(f"  [FAIL] Kubernetes Nesne Türü ({k}) EKSİK!")

    # 2. Deployment ve Container Özellik Kontrolleri
    for doc in docs:
        if re.search(r"^kind:\s+Deployment", doc, re.MULTILINE):
            dep_name = re.search(r"name:\s+([\w-]+)", doc)
            name_str = dep_name.group(1) if dep_name else "Unknown"
            
            # SecurityContext Check
            total += 1
            if "allowPrivilegeEscalation: false" in doc:
                print(f"  [PASS] Deployment ({name_str}) -> allowPrivilegeEscalation: false Doğrulandı")
                passed += 1
            else:
                print(f"  [FAIL] Deployment ({name_str}) -> SecurityContext Eksik!")
                
            # Resources Check
            total += 1
            if "resources:" in doc and "requests:" in doc and "limits:" in doc:
                print(f"  [PASS] Deployment ({name_str}) -> Resources Requests & Limits Doğrulandı")
                passed += 1
            else:
                print(f"  [FAIL] Deployment ({name_str}) -> Resources Eksik!")

            # Probes Check
            total += 1
            if "readinessProbe:" in doc or "startupProbe:" in doc:
                print(f"  [PASS] Deployment ({name_str}) -> Health Probes Doğrulandı")
                passed += 1
            else:
                print(f"  [FAIL] Deployment ({name_str}) -> Health Probes Eksik!")

    return passed, total

def validate_prod_structure():
    print("\n--- 2. Production Overlay Yapısal Politika Testleri ---")
    prod_raw = get_kustomize_manifest("k8s/overlays/prod")
    docs = split_yaml_docs(prod_raw)
    
    passed = 0
    total = 0

    # App Replicas == 2 Check
    total += 1
    app_match = re.search(r"name:\s+app-deployment[\s\S]*?replicas:\s+(\d+)", prod_raw)
    if app_match and app_match.group(1) == "2":
        print("  [PASS] Production App Deployment Replicas == 2 (High Availability)")
        passed += 1
    else:
        print("  [FAIL] Production App Deployment Replicas != 2!")

    # phpMyAdmin Replicas == 0 Check
    total += 1
    pma_match = re.search(r"name:\s+pma-deployment[\s\S]*?replicas:\s+(\d+)", prod_raw)
    if pma_match and pma_match.group(1) == "0":
        print("  [PASS] Production phpMyAdmin Replicas == 0 (Güvenlik Kısıtlaması Pasif)")
        passed += 1
    else:
        print("  [FAIL] Production phpMyAdmin Replicas != 0!")

    # Ingress TLS & cert-manager Check
    total += 1
    if "secretName: app-tls-cert" in prod_raw and "cert-manager.io/cluster-issuer: letsencrypt-prod" in prod_raw:
        print("  [PASS] Production Ingress TLS ve cert-manager ClusterIssuer Doğrulandı")
        passed += 1
    else:
        print("  [FAIL] Production Ingress TLS / cert-manager Eksik!")

    return passed, total

def main():
    print("==========================================================")
    print(" 🐍 Python Kubernetes Yapısal Nesne Doğrulayıcısı (Deep Validator)")
    print("==========================================================")

    p1, t1 = validate_base_structure()
    p2, t2 = validate_prod_structure()

    passed_total = p1 + p2
    tests_total = t1 + t2

    print("\n==========================================================")
    print(f" 📊 PYTHON DEEP VALIDATION SONUCU: {passed_total}/{tests_total} Başarılı")
    print("==========================================================")

    if passed_total != tests_total:
        sys.exit(1)

if __name__ == "__main__":
    main()
