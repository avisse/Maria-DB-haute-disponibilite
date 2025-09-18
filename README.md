# MariaDB – Réplication Master ➜ Slave (Docker)

**Contenu**
- `docker-compose.yml` : stack master + (optionnel) slave
- `master/` : config du master (binlog, server-id…)
- (Les volumes/données/dumps ne sont PAS versionnés)

## Démarrer
```bash
docker compose up -d
