# MariaDB – Haute Disponibilité avec Réplication Master ➜ Slave

## 🎯 Objectif
Mettre en place une **infrastructure MariaDB tolérante aux pannes** en utilisant la réplication **Master ➜ Slave** via Docker.  
Ce projet illustre une architecture de base pour assurer **la redondance et la disponibilité** des données.

---

## 📂 Contenu du dépôt
- `docker-compose.yml` → stack Docker pour MariaDB (master + optionnel slave).  
- `master/` → configuration spécifique du serveur **master** (binlog, server-id…).  
- `.gitignore` → exclut les volumes `data/`, dumps SQL, fichiers de logs, et secrets.  

❌ Les données (`data/`), dumps SQL (`*.sql`) et secrets (`.env`) ne sont **pas versionnés**.

---

## 🚀 Démarrage rapide

### 1️⃣ Lancer l’infrastructure
```bash
docker compose up -d
2️⃣ Vérifier que le master tourne
bash
Copier le code
docker ps
⚙️ Configuration de la réplication
🔹 Master – Activer le binlog
Dans master/my.cnf :

ini
Copier le code
[mysqld]
server-id=1
log_bin=mysql-bin
binlog_format=ROW
Puis redémarrer le container master :

bash
Copier le code
docker compose restart master
🔹 Créer l’utilisateur de réplication
Se connecter au master :

bash
Copier le code
docker exec -it master mariadb -u root -p
Puis exécuter :

sql
Copier le code
CREATE USER 'repl'@'%' IDENTIFIED BY 'motdepasse';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
📌 Note bien le File et la Position retournés.

🔹 Slave – Pointer vers le master
Sur le slave :

sql
Copier le code
CHANGE MASTER TO
  MASTER_HOST='master',
  MASTER_USER='repl',
  MASTER_PASSWORD='motdepasse',
  MASTER_LOG_FILE='mysql-bin.000001',
  MASTER_LOG_POS=12345;

START SLAVE;
SHOW SLAVE STATUS\G;
✅ Vérifie que Slave_IO_Running et Slave_SQL_Running sont sur Yes.
