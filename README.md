# MariaDB – Haute disponibilité avec réplication **Master ➜ Slave** (Docker)

> Projet pédagogique / démonstrateur : mettre en place une **réplication MariaDB asynchrone** entre deux conteneurs Docker (`mariadb_master`, `mariadb_slave`) sur Debian 12, documentée et **reproductible**.

---

##  Objectifs

- Déployer une réplication **Master ➜ Slave** basée sur **binlogs** (format **ROW**).
- Garantir la **persistance** des données (volumes) et l’**isolement réseau** (bridge dédié).
- Documenter **pas à pas** : fichiers, commandes, tests de validation et dépannage.
- Bonnes pratiques : secrets hors Git, utilisateur de réplication dédié, `read_only` côté slave.

---

## Architecture

```
[Docker network: dbnet]
             ┌───────────────────────┐
             │  mariadb_master       │
             │  - server-id: 1       │
   writes →  │  - log_bin (ROW)      │
 binlog ---> │  - user 'repl'        │
             └─────────┬─────────────┘
                       │  CHANGE MASTER TO…
                       ▼
             ┌───────────────────────┐
             │  mariadb_slave        │
             │  - server-id: 2       │
             │  - read_only=ON       │
             │  - Slave_IO/SQL=YES   │
             └───────────────────────┘
```

- **Réseau** : bridge Docker privé (`dbnet`).
- **Volumes** : un volume persistant par nœud (`master-data`, `slave-data`).

---

## 🗂Arborescence du dépôt

```
mariadb-ha-replication/
├─ docker-compose.yml              # Orchestration des 2 services
├─ .env.example                    # Variables (mdp root, DB, user réplication…)
├─ .gitignore                      # Ignore data/, dumps, secrets
├─ master/
│  └─ my.cnf                       # conf MariaDB master (binlog, ROW, id)
├─ slave/
│  └─ my.cnf                       # conf MariaDB slave (read_only, id)
└─ docs/
   └─ HOWTO.md                     # (optionnel) pas-à-pas détaillé
```

> **Important** : copier `.env.example` vers `.env` et **ne jamais** versionner `.env`, `*.sql` ou les sous-dossiers `data/`.

---

##  Prérequis

- Hôte Debian 12 (ou toute machine avec **Docker** + **Docker Compose v2**).
- Accès Internet pour tirer les images.
- Port **3307** libre si vous mappez MySQL du master vers l’hôte (optionnel).

---

## ⚙Fichiers clés

### 1) `docker-compose.yml`

```yaml
version: "3.9"

networks:
  dbnet:

volumes:
  master-data:
  slave-data:

services:
  mariadb_master:
    image: mariadb:11
    container_name: mariadb_master
    restart: unless-stopped
    environment:
      - MARIADB_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MARIADB_DATABASE=${DEMO_DB}
    ports:
      - "3307:3306"            # (optionnel) exposer le master sur l'hôte
    networks: [dbnet]
    volumes:
      - master-data:/var/lib/mysql
      - ./master/my.cnf:/etc/mysql/conf.d/master.cnf:ro
    healthcheck:
      test: ["CMD-SHELL", "mariadb-admin ping -uroot -p${MYSQL_ROOT_PASSWORD} --silent"]
      interval: 5s
      timeout: 3s
      retries: 20

  mariadb_slave:
    image: mariadb:11
    container_name: mariadb_slave
    restart: unless-stopped
    environment:
      - MARIADB_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    networks: [dbnet]
    depends_on:
      mariadb_master:
        condition: service_healthy
    volumes:
      - slave-data:/var/lib/mysql
      - ./slave/my.cnf:/etc/mysql/conf.d/slave.cnf:ro
    healthcheck:
      test: ["CMD-SHELL", "mariadb-admin ping -uroot -p${MYSQL_ROOT_PASSWORD} --silent"]
      interval: 5s
      timeout: 3s
      retries: 20
```

### 2) `master/my.cnf`

```ini
[mysqld]
server-id=1
log_bin=mysql-bin
binlog_format=ROW
```

### 3) `slave/my.cnf`

```ini
[mysqld]
server-id=2
read_only=ON
relay_log=relay-bin
```

### 4) `.env.example`

```dotenv
# Root & DB
MYSQL_ROOT_PASSWORD=ChangeMeStrong!
DEMO_DB=demo

# Réplication
REPL_USER=repl
REPL_PASSWORD=ChangeMeRepl!
```



---

##  Mise en route (pas à pas)

### 1. Démarrer l’infra

```bash
cp .env.example .env           # personnalisez vos valeurs
docker compose up -d
docker ps                      # vérifier que master et slave tournent
```

### 2. Créer l’utilisateur de réplication (master)

```bash
docker exec -it mariadb_master mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
  CREATE USER '${REPL_USER}'@'%' IDENTIFIED BY '${REPL_PASSWORD}';
  GRANT REPLICATION SLAVE ON *.* TO '${REPL_USER}'@'%';
  FLUSH PRIVILEGES;
"
```

### 3. Relever les coordonnées binlog (master)

```bash
docker exec -it mariadb_master mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
  FLUSH TABLES WITH READ LOCK;
  SHOW MASTER STATUS;
"
# Notez les colonnes 'File' (ex: mysql-bin.000002) et 'Position' (ex: 631)
# Puis (optionnel) déverrouillez :
docker exec -it mariadb_master mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "UNLOCK TABLES;"
```

### 4. Pointer le slave vers le master

```bash
docker exec -it mariadb_slave mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
  CHANGE MASTER TO
    MASTER_HOST='mariadb_master',
    MASTER_USER='${REPL_USER}',
    MASTER_PASSWORD='${REPL_PASSWORD}',
    MASTER_LOG_FILE='mysql-bin.000002',
    MASTER_LOG_POS=631;
  START SLAVE;
"
```

### 5. Vérifier l’état de réplication (slave)

```bash
docker exec -it mariadb_slave mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "SHOW SLAVE STATUS\G"
```

Vous devez voir :
- `Slave_IO_Running: Yes`
- `Slave_SQL_Running: Yes`

---

##  Test de validation

Créer une table et une ligne **sur le master** :

```bash
docker exec -it mariadb_master mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
  USE ${DEMO_DB};
  CREATE TABLE IF NOT EXISTS test_ecf (id INT AUTO_INCREMENT PRIMARY KEY, stamp VARCHAR(64));
  INSERT INTO test_ecf(stamp) VALUES('2025');
  SELECT * FROM test_ecf;
"
```

Contrôler que la donnée est visible **sur le slave** :

```bash
docker exec -it mariadb_slave mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" -e "
  USE ${DEMO_DB};
  SELECT * FROM test_ecf;
"
```

---

##  Sécurité & bonnes pratiques

- versionner `.env`, `*.sql`, `data/` → secrets et données restent hors Git.
- Utilisateur de réplication **dédié** (`REPL_USER`) avec privilèges **minimaux**.
- `read_only=ON` côté slave pour éviter une écriture accidentelle.
- La **réplication n’est pas une sauvegarde** : prévoir des **backups** (dumps, snapshots) + **tests de restauration**.
- Surveiller `SHOW SLAVE STATUS\G` (alertes si `Slave_IO_Running` ou `Slave_SQL_Running` passent à `No`).

---

## 🛠Dépannage rapide

- **`Slave_IO_Running/Slave_SQL_Running = No`**  
  Vérifier `MASTER_HOST/USER/PASSWORD`, `MASTER_LOG_FILE/POS`, réseau (`docker exec mariadb_slave ping mariadb_master`), et lire `Last_IO_Error` / `Last_SQL_Error` dans `SHOW SLAVE STATUS\G`.

- **Pas de données sur le slave**  
  Confirmer `log_bin` + `binlog_format=ROW` côté master ; refaire une écriture de test.

- **Problèmes de droits**  
  Refaire : `GRANT REPLICATION SLAVE ...` + `FLUSH PRIVILEGES;`

---

## Commandes utiles

```bash
# Shell rapide dans un conteneur
docker exec -it mariadb_master bash

# Client MariaDB root
docker exec -it mariadb_master mariadb -uroot -p"$MYSQL_ROOT_PASSWORD"

# Redémarrer uniquement le master
docker compose restart mariadb_master

# Arrêt & suppression propre
docker compose down
```

---
