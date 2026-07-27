FROM php:8.2-fpm-alpine

# Gerekli sistem paketlerini yükle ve Composer kur
RUN apk add --no-cache curl git unzip \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /var/www/html

# Composer ile GuzzleHTTP kütüphanesini indir
RUN composer require guzzlehttp/guzzle --no-interaction

# Uygulama kaynak kodlarını kopyala
COPY . /var/www/html/
