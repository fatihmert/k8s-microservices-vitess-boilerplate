<?php
require_once __DIR__ . '/vendor/autoload.php';

use GuzzleHttp\Client;

$mysqlHost = "mysql-service";
$redisHost = "redis-service";
$vitessHost = "vtgate-zone1-service";

echo "<h1>Kubernetes Microservice, Redis & Vitess Sharding Testi</h1>";

// 1. Standart MySQL Soket Bağlantı Kontrolü
$fpMysql = @fsockopen($mysqlHost, 3306, $errno, $errstr, 3);
if ($fpMysql) {
    fclose($fpMysql);
    echo "<p style=\"color:green;\">✅ <b>MySQL ($mysqlHost:3306)</b> bağlantısı başarılı!</p>";
} else {
    echo "<p style=\"color:red;\">❌ MySQL Servisine Ulaşılamadı: $errstr ($errno)</p>";
}

// 2. Redis Soket Bağlantı Kontrolü
$fpRedis = @fsockopen($redisHost, 6379, $errno, $errstr, 3);
if ($fpRedis) {
    fclose($fpRedis);
    echo "<p style=\"color:green;\">✅ <b>Redis ($redisHost:6379)</b> bağlantısı başarılı!</p>";
} else {
    echo "<p style=\"color:red;\">❌ Redis Servisine Ulaşılamadı: $errstr ($errno)</p>";
}

// 3. Vitess CNCF MySQL Sharding Proxy Bağlantı Kontrolü
$fpVitess = @fsockopen($vitessHost, 15306, $errno, $errstr, 3);
if ($fpVitess) {
    fclose($fpVitess);
    echo "<p style=\"color:green;\">✅ <b>Vitess Sharded MySQL Proxy ($vitessHost:15306)</b> bağlantısı başarılı!</p>";
} else {
    echo "<p style=\"color:orange;\">ℹ️ <b>Vitess Proxy ($vitessHost:15306)</b> henüz hazır değil veya bekleniyor (Vitess Operator gerektirir).</p>";
}

// 4. GuzzleHTTP İle Dış Dünya (IP API) Bağlantı Testi
echo "<h3>GuzzleHTTP İle Dış API (ipify) Çağrısı:</h3>";
try {
    $client = new Client(['timeout' => 5.0]);
    $response = $client->get('https://api.ipify.org?format=json');
    $data = json_decode($response->getBody(), true);
    
    echo "<p style=\"color:blue;\">🌐 Dış Dünya IP Adresiniz: <b>" . htmlspecialchars($data['ip']) . "</b></p>";
} catch (\Exception $e) {
    echo "<p style=\"color:red;\">❌ GuzzleHTTP İsteği Başarısız: " . htmlspecialchars($e->getMessage()) . "</p>";
}
