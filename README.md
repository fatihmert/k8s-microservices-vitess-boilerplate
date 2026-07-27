# Enterprise Kubernetes Microservices & Vitess Sharding Boilerplate

[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.30+-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kubernetes.io/)
[![Vitess](https://img.shields.io/badge/Vitess-CNCF_Graduated-E84A5F?style=for-the-badge&logo=vitess&logoColor=white)](https://vitess.io/)
[![PHP](https://img.shields.io/badge/PHP-8.2_FPM-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://www.php.net/)
[![Redis](https://img.shields.io/badge/Redis-7.0_Cache-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io/)
[![MySQL](https://img.shields.io/badge/MySQL-8.0_DB-4479A1?style=for-the-badge&logo=mysql&logoColor=white)](https://www.mysql.com/)
[![Kustomize](https://img.shields.io/badge/Kustomize-Base_%26_Overlays-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)](https://kustomize.io/)

---

## 1. Projenin Amacı

Bu proje; modern, ölçeklenebilir ve yüksek erişilebilirlikli mikroservis mimarisini bulut ve yerel Kubernetes kümeleri üzerinde çalıştırmak için hazırlanmış **Production-Ready Kubernetes & Vitess Sharding Başlangıç Şablonudur (Boilerplate)**.

Sistem; web sunucu (Nginx), uygulama katmanı (PHP-FPM), önbellek katmanı (Redis 7), birincil veritabanı (MySQL 8.0) ve yatay veritabanı bölümleme/ölçeklendirme altyapısı olan **Vitess Sharded MySQL Proxy (`VTGate`)** bileşenlerini Kustomize yapısıyla sunar.

---

## 2. Sistem Mimarisi

Mimaride Ingress Controller trafiği kabul eder ve ilgili servislere yönlendirir:

```text
Client
  ↓
Ingress Controller
  ├── app-service (ClusterIP:80)
  │     └── App Pod (Multi-Container)
  │           ├── Nginx Alpine (FastCGI -> 127.0.0.1:9000)
  │           └── PHP 8.2-FPM
  │                 ├── MySQL 8.0 (mysql-service:3306)
  │                 ├── Redis 7 (redis-service:6379)
  │                 └── Vitess VTGate (vtgate-zone1-service:15306)
  │                       ├── Vitess Tablets (MySQL Shards)
  │                       ├── vtctld (Vitess Admin)
  │                       └── etcd topology
  │
  └── pma-service (ClusterIP:8080 - Dev ortamı veya Private Admin Port-Forwarding)
        └── phpMyAdmin
```

---

## 3. Bileşenler

| Bileşen | Sürüm / Detay | Açıklama |
| :--- | :--- | :--- |
| **Nginx** | `nginx:alpine` | Web sunucu & PHP-FPM ters proxy (Port 80) |
| **PHP-FPM** | `php:8.2-fpm-alpine` | Özel imaj (GuzzleHTTP + Composer), Port 9000 |
| **Redis** | `redis:7-alpine` | Ön bellek & Oturum katmanı (Port 6379) |
| **MySQL** | `mysql:8.0` | Birincil ilişkisel veritabanı (Port 3306, PVC ile kalıcı) |
| **Vitess** | `planetscale.com/v2` (VitessCluster) | CNCF mezunu yatay MySQL bölümleme & Proxy (Port 15306) |
| **phpMyAdmin** | `phpmyadmin/phpmyadmin` | Veritabanı yönetim arayüzü (Dev: `pma.local`, Prod: Güvenlik amacıyla kapalı) |
| **HPA** | `autoscaling/v2` | CPU (%70) ve RAM (%80) metriklerine göre (Min 2 - Max 10 Pod) otomatik ölçeklendirme |
| **Kustomize** | `base`, `dev`, `prod` | Çevreye özel (Dev/Prod) konfigürasyon ayrımı ve deklaratif yama yönetimi |

---

## 4. Klasör Yapısı

```text
.
├── .dockerignore                 # Docker build hariç tutma kuralları
├── app/                          # PHP Uygulama Kaynak Kodları ve Dockerfile
│   ├── Dockerfile                # PHP 8.2-FPM + Composer + GuzzleHTTP imaj tanımı
│   └── index.php                 # Bağlantı ve API sağlık test kodları
├── kustomization.yaml            # Kök dizin varsayılan Kustomize tanımı (dev katmanını gösterir)
├── README.md                     # Sistem dokümantasyonu
└── k8s/                          # Kubernetes Manifestleri Klasörü
    ├── base/                     # Temel Altyapı Tanımları
    │   ├── kustomization.yaml    # Base Kustomize manifest listesi & secret/configmap jeneratörleri
    │   ├── apps/                 # Uygulama Katmanı Manifestleri
    │   │   ├── app.yaml          # Nginx + PHP-FPM Deployment & Service (Probes, Exporter Sidecar)
    │   │   ├── hpa.yaml          # Horizontal Pod Autoscaler
    │   │   ├── ingress.yaml      # HTTP Ingress Controller & Local Domain Kuralları
    │   │   └── phpmyadmin.yaml   # phpMyAdmin Deployment & Service
    │   ├── configs/              # Konfigürasyon Dosyaları
    │   │   ├── default.conf      # Nginx Server & Status Locations
    │   │   └── users.json        # Vitess VTGate Statik Kimlik Doğrulama Dosyası
    │   ├── datastores/           # Veritabanı & Cache Katmanı
    │   │   ├── mysql.yaml        # MySQL Secret, PVC, mysqld-exporter Sidecar
    │   │   ├── redis.yaml        # Redis Deployment (LRU Eviction), redis-exporter Sidecar
    │   │   └── vitess.yaml       # VitessCluster CRD & VTGate Service
    │   └── monitoring/           # Gözlemlenebilirlik (Observability) Tanımları
    │       ├── servicemonitors.yaml # Nginx, MySQL, Redis ServiceMonitors
    │       ├── vitess-podmonitor.yaml # Vitess PodMonitor (VTGate, VTTablet)
    │       ├── prometheus-rules.yaml # Alertmanager Alarm Kuralları (RED & High Memory)
    │       └── grafana-dashboard-configmap.yaml # Grafana Pano ConfigMap (Auto-Discovery)
    └── overlays/                 # Ortama Özel Yapılandırmalar
        ├── dev/                  # Development Ortamı
        │   └── kustomization.yaml
        └── prod/                 # Production Ortamı
            ├── kustomization.yaml
            ├── monitoring/
            │   └── values-prod.yaml       # kube-prometheus-stack Production Helm Konfigürasyonu
            └── patches/
                ├── app-patch.yaml         # Prod Replicas (2) & Pod Anti-Affinity
                ├── ingress-patch.yaml     # Prod SSL/TLS & cyclechain.io Ingress Yaması
                └── phpmyadmin-patch.yaml  # Prod Güvenlik Yaması (Replicas: 0)
```

---

## 5. Gereksinimler

* **Kubernetes Cluster**: v1.26+ (Minikube, MicroK8s, EKS, GKE, AKS)
* **kubectl**: v1.26+
* **Vitess Operator**: Kümede `VitessCluster` CRD'lerinin tanımlı olması gerekir.
* **NGINX Ingress Controller** & **cert-manager** (Production SSL için).

---

## 6. Docker Image Build İşlemi

Geliştirme ortamında (örneğin Minikube):

```bash
eval $(minikube -p minikube docker-env)
docker build -t my-php-app:v1 ./app
```

Veya Minikube doğrudan yerel imaj derleme:

```bash
minikube image build -t my-php-app:v1 ./app
```

---

## 7. Development Kurulumu

Geliştirme ortamında varsayılan domainler: `app.local`, `pma.local`, `grafana.local`, `prometheus.local`.

1. **Dev Ortamını Yayınlama**:
   ```bash
   kubectl apply -k k8s/overlays/dev
   ```

2. **Hosts Dosyası Tanımlaması (`/etc/hosts`)**:
   ```bash
   sudo sh -c 'echo "127.0.0.1 app.local pma.local grafana.local prometheus.local" >> /etc/hosts'
   ```

3. **Erişim**:
   * Uygulama: `http://app.local`
   * phpMyAdmin: `http://pma.local`
   * Grafana Panosu: `http://grafana.local`
   * Prometheus Arayüzü: `http://prometheus.local`

---

## 8. Production Kurulumu

Production ortamında canlı domainler: `app.cyclechain.io`, `grafana.cyclechain.io`, `prometheus.cyclechain.io` (SSL/TLS ile).

1. **Production Ortamını Yayınlama**:
   ```bash
   kubectl apply -k k8s/overlays/prod
   ```

2. **Gözlemlenen Production Özellikleri**:
   * `app-deployment` min 2 replica ve **Pod Anti-Affinity** ile farklı node'larda çalışır.
   * Ingress `cert-manager` Let's Encrypt entegrasyonu ile SSL sertifikalarını otomatik yönetir (`app.cyclechain.io`, `grafana.cyclechain.io`, `prometheus.cyclechain.io`).
   * `phpmyadmin` kamuya açık değildir (replicas: 0).

---

## 9. Kustomize Kullanımı

Manifestlerin çıktısını uygulamadan doğrulamak için:

```bash
# Base katmanı kustomize doğrulaması
kubectl kustomize k8s/base

# Dev overlay kustomize doğrulaması
kubectl kustomize k8s/overlays/dev

# Prod overlay kustomize doğrulaması
kubectl kustomize k8s/overlays/prod
```

Farkları görüntülemek için:

```bash
kubectl diff -k k8s/overlays/prod
```

---

## 10. Ingress ve Domain Yapılandırması

* **Base / Dev Ingress**: `app.local` ve `pma.local` host adları ile yönlendirme sağlar.
* **Prod Ingress**: `app.cyclechain.io` alan adı için TLS sonlandırma sağlar. `proxy-body-size: 64m` ve zaman aşımı ayarları (connect/read/send timeout: 60s) yapılandırılmıştır.

---

## 11. TLS ve cert-manager Kurulumu

Production ortamında `cert-manager` Let's Encrypt `ClusterIssuer` kullanır. `k8s/overlays/prod/patches/ingress-patch.yaml` dosyasındaki annotation:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
  nginx.ingress.kubernetes.io/ssl-redirect: "true"
```

Sertifika secret'ı (`app-tls-cert`) cert-manager tarafından otomatik oluşturulur.

---

## 12. Secret Yönetimi

Projede hassas veriler doğrudan Git deposunda açık metin saklanmamalıdır.

* **MySQL Root Şifresi**: `k8s/base/datastores/mysql.yaml` içerisinde varsayılan geliştirme değeri yer almaktadır.
* **VTGate Kimlik Bilgileri**: `k8s/base/configs/users.json` dosyasından `secretGenerator` vasıtasıyla `vtgate-auth` Secret'ına dönüştürülür.
* **Production Önerisi**: Sealed Secrets, External Secrets Operator veya Vault kullanılmalıdır. Örnek gizli bilgi şablonları için `secret.example.yaml` ve `users.example.json` referans alınmalıdır.

---

## 13. MySQL Bağlantısı

Uygulama Pod'ları veritabanına küme içi DNS ile erişir:

```text
Host: mysql-service
Port: 3306
Secret: mysql-secret (Key: MYSQL_ROOT_PASSWORD)
```

Bağlantı doğrulama testi:

```bash
kubectl run mysql-client --rm -it --restart=Never --image=mysql:8.0 -n <namespace> -- mysql -h mysql-service -u root -p
```

---

## 14. Redis Bağlantısı

Redis servis bilgileri:

```text
Host: redis-service
Port: 6379
Eviction Policy: allkeys-lru (Max Memory: 200mb)
```

Bağlantı doğrulama testi:

```bash
kubectl run redis-client --rm -it --restart=Never --image=redis:7-alpine -n <namespace> -- redis-cli -h redis-service ping
```

---

## 15. Vitess Bağlantısı

Vitess VTGate MySQL Proxy erişim bilgileri:

```text
Host: vtgate-zone1-service
Port: 15306
User: app (users.json içerisinde tanımlı)
```

VTGate test komutu:

```bash
kubectl run mysql-client --rm -it --restart=Never --image=mysql:8.0 -n <namespace> -- mysql -h vtgate-zone1-service -P 15306 -u app -p
```

---

## 16. VTGate Authentication

VTGate statik kimlik doğrulaması `k8s/base/configs/users.json` konfigürasyonu üzerinden yürütülür. `k8s/base/kustomization.yaml` içerisindeki `secretGenerator` bunu `vtgate-auth` Secret'ı haline getirir ve VitessCluster tanımına bağlar.

---

## 17. phpMyAdmin Erişim Güvenliği

* **Dev Ortamı**: `http://pma.local` üzerinden erişilebilir.
* **Prod Ortamı**: Güvenlik açığı oluşmaması için production yamasında (`k8s/overlays/prod/patches/phpmyadmin-patch.yaml`) `replicas: 0` olarak ayarlanmış ve public Ingress'ten kaldırılmıştır.
* **Yönetici Geçici Erişimi (Port-Forward)**:
  Gerekli durumlarda `replicas: 1` yapılıp port-forwarding ile güvenli erişim sağlanır:
  ```bash
  kubectl port-forward svc/pma-service 8081:8080 -n <namespace>
  ```

---

## 18. HPA Çalışma Mantığı

`k8s/base/apps/hpa.yaml` kaynağı `app-deployment` kaynağını izler:

* **Minimum Replica**: 2
* **Maksimum Replica**: 10
* **Hedef CPU**: %70 ortalama kullanım
* **Hedef Memory**: %80 ortalama kullanım

HPA'nın doğru çalışabilmesi için `app.yaml` içinde hem Nginx hem de PHP-FPM konteynerleri için CPU/RAM `requests` değerleri tanımlanmıştır.

---

## 19. Storage ve PVC Kullanımı

MySQL verileri `mysql-pvc` PersistentVolumeClaim ile saklanır (`storage: 2Gi`, `accessModes: ReadWriteOnce`). Pod yeniden başlatılsa bile veri kalıcılığı korunur.

---

## 20. Backup ve Restore

### MySQL Yedekleme (Dump)
```bash
kubectl exec deployment/mysql-deployment -n <namespace> -- mysqldump -u root -p<password> --all-databases > backup.sql
```

### MySQL Geri Yükleme (Restore)
```bash
kubectl exec -i deployment/mysql-deployment -n <namespace> -- mysql -u root -p<password> < backup.sql
```

---

## 21. Deployment Güncelleme

Yeni uygulama imajını yayınlamak için:

```bash
kubectl set image deployment/app-deployment php-container=my-php-app:v2 -n <namespace>
```

Rollout durumunu izleme:

```bash
kubectl rollout status deployment/app-deployment -n <namespace>
```

---

## 22. Rollback

Hatalı bir güncellemede önceki sürüme dönmek için:

```bash
# Geçmiş güncellemeleri listele
kubectl rollout history deployment/app-deployment -n <namespace>

# Bir önceki sürüme geri dön
kubectl rollout undo deployment/app-deployment -n <namespace>
```

---

## 23. Log Görüntüleme

```bash
# Nginx konteyner logları
kubectl logs -f deployment/app-deployment -n <namespace> -c nginx-container

# PHP-FPM konteyner logları
kubectl logs -f deployment/app-deployment -n <namespace> -c php-container

# MySQL logları
kubectl logs -f deployment/mysql-deployment -n <namespace>
```

---

## 24. Hata Ayıklama (Troubleshooting)

```bash
# Pod durumlarını ayrıntılı görüntüleme
kubectl get pods -n <namespace> -o wide

# Pod olaylarını ve probe hatalarını inceleme
kubectl describe pod <pod-name> -n <namespace>

# Çöken konteynerin önceki loglarını okuma
kubectl logs <pod-name> -n <namespace> -c <container-name> --previous
```

---

## 25. Sistemi Kaldırma

```bash
# Dev ortamını kaldır
kubectl delete -k k8s/overlays/dev

# Prod ortamını kaldır
kubectl delete -k k8s/overlays/prod
```

> ⚠️ **Uyarı**: Kümeyi silmek PVC verilerini de silebilir. Kalıcı verilerinizi yedeklediğinizden emin olun.

---

## 26. Bilinen Riskler

1. **MySQL Tek Replica**: `mysql-deployment` tek replica olarak çalışmaktadır. Fiziksel node arızasında HA sağlamaz. High Availability için StatefulSet veya Vitess sharding tercih edilmelidir.
2. **Redis Restart Oturum Kaybı**: Redis ephemeral (AOF/RDB kapalı) çalıştığı için Pod yeniden başladığında önbellek ve oturum verileri temizlenir.
3. **Vitess etcd Verisi**: Vitess topology etcd backend'i sıfırlanırsa Vitess sharding metadata'sı kaybolur.

---

## 27. Production Önerileri

* **Secret Yönetimi**: Production parolalarını Git deposuna yazmayın; HashiCorp Vault veya External Secrets Operator kullanın.
* **Database High Availability**: MySQL için Vitess sharding kümesini birincil veri deposu olarak ölçeklendirin.
* **Network Policies**: Konteynerler arası trafiği kısıtlamak için varsayılan NetworkPolicy kurallarını aktif edin.
* **Monitoring & Alerting**: Prometheus & Grafana ile Pod, CPU/RAM ve veritabanı metriklerini izleyin.

---

## 28. Otomatik Test ve Doğrulama (Testing & CI/CD)

Projede manifest politika kurallarını ve canlı küme entegrasyonunu doğrulamak için `tests/` dizininde otomatik test scriptleri bulunmaktadır:

1. **Statik Manifest ve Politika Testleri**:
   Kustomize derlemesini, probe tanımlarını, kaynak limitlerini ve prod güvenlik kurallarını kontrol eder:
   ```bash
   ./tests/test_k8s_manifests.sh
   ```

2. **Canlı Küme E2E Entegrasyon Testi**:
   Aktif bir Kubernetes kümesine (Minikube, Kind, GKE vb.) dağıtım yapıp rollout ve veritabanı bağlantı durumlarını doğrular:
   ```bash
   ./tests/e2e_cluster_test.sh default dev
   ```

---

## 29. Prometheus & Grafana Monitoring (Observability)

Sistemin izlenebilirliği, ayrı bir `monitoring` namespace'inde çalışan **kube-prometheus-stack** Helm chart'ı ve uygulamaya özel deklaratif Kustomize kaynakları (`ServiceMonitor`, `PodMonitor`, `PrometheusRule`) ile yönetilir.

### 1. `kube-prometheus-stack` Kurulumu (Helm)

```bash
# Prometheus Helm Reposunu Ekleme
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Development Basit Kurulum
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace

# Production Kurulum (Kalıcı PVC Disk, SSL Ingress & Custom Retention)
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --values k8s/overlays/prod/monitoring/values-prod.yaml
```

### 2. Uygulama Exporter ve Monitoring Bileşenleri

* **Nginx Exporter**: `app-deployment` Pod'u içine sidecar olarak eklenmiştir (Port 9113). `nginx-servicemonitor.yaml` ile taranır.
* **MySQL Exporter**: `mysql-deployment` Pod'u içine `mysqld-exporter` sidecar olarak eklenmiştir (Port 9104). `mysql-servicemonitor.yaml` ile taranır.
* **Redis Exporter**: `redis-deployment` Pod'u içine `redis_exporter` sidecar olarak eklenmiştir (Port 9121). `redis-servicemonitor.yaml` ile taranır.
* **Vitess PodMonitor**: Vitess `vtgate` proxy ve tablet metrikleri `vitess-podmonitor.yaml` ile dinamik olarak taranır.
* **Alertmanager Alarmları**: `prometheus-rules.yaml` ile tanımlanmış High Memory (>%85), MySQL Down, Redis Eviction ve VTGate Down alarm kuralları.
* **Grafana Dashboard**: `grafana-dashboard-configmap.yaml` ile Grafana sidecar'ına otomatik yüklenen genel bakış panosu.

