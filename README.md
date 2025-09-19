# Environnement Docker : PHP 8.2 + Composer + Client MySQL

Projet **séparé** qui recrée l'image/contener PHP + Composer + extensions MySQL.

## Lancer
```bash
docker compose up -d --build
docker exec -it php_composer_container bash
```

## Vérifier
```bash
php -v
composer --version
mysql --version
```

ℹ️ Le conteneur reste actif grâce à `CMD ["tail", "-f", "/dev/null"]`.
