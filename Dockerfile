# Image PHP CLI avec client MySQL + Composer
FROM php:8.2-cli

RUN apt-get update && apt-get install -y --no-install-recommends         default-mysql-client unzip git curl zip         && docker-php-ext-install pdo pdo_mysql         && rm -rf /var/lib/apt/lists/*

# Installer Composer
RUN curl -sS https://getcomposer.org/installer | php --         --install-dir=/usr/local/bin --filename=composer

# Empêche l'arrêt immédiat du conteneur (utile en dev)
CMD ["tail", "-f", "/dev/null"]
