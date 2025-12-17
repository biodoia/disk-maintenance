# Problema
Serve automatizzare analisi e liberazione spazio su root `/` con criteri aggressivi ma a basso rischio, evitando interventi distruttivi (es. rimozione immagini Docker in uso).

# Stato attuale (rilevato)
- `crontab` è presente, ma il servizio `cronie` risulta `disabled/inactive`.
- Sono già presenti systemd timers di sistema (es. `logrotate.timer`, `pamac-cleancache.timer`).

# Scelte
- Scheduling: usare **systemd** (timers) (più robusto di cron: logging via journal, dipendenze, random delay, facile enable/disable).
- Due modalità:
  - **Learning mode (costante)**: raccoglie metriche e “impara” trend (report-only, nessuna azione distruttiva).
  - **Cleanup mode (guarded)**: esegue cleanup pre-approvato solo se `/` supera soglia (>=85%).
  - **Emergency mode**: se `/` entra in stato critico, esegue azioni più aggressive ma ancora “safe”, e invoca un agent headless per analisi/triage.

# Proposta tecnica
## 1) Script unico con subcommand (idempotente)
Creare uno script (es. `/usr/local/sbin/disk-maintenance`) con subcommand:
- `report` (learning):
  - raccoglie `df` e un top-N di `du` su path noti (es. `/var/cache`, `/var/log`, `/var/lib/docker`) con limiti di profondità/tempo;
  - salva un record JSONL in `/var/lib/disk-maintenance/history.jsonl` + log su journald.
- `cleanup` (guarded):
  - check soglia: se `/` <85% esce dopo report;
  - pacman cache: `paccache -rk1`;
  - journald: `journalctl --vacuum-size=200M`;
  - coredumps: elimina solo quelli più vecchi di 14 giorni;
  - snap: rimuove revisioni `disabled` + imposta retention (es. `refresh.retain=2`);
  - docker: `docker system prune -f` (no `-a`);
  - report finale.
- `emergency`:
  - trigger: `/` >=95% oppure free space < 1G (configurabile);
  - azioni “safe ma aggressive” (sempre bounded):
    - `paccache -rk1` (again);
    - `journalctl --vacuum-size=50M`;
    - snap cleanup disabled (again);
    - docker: `docker system prune -f` (no `-a`);
    - report finale;
  - invoca una CLI agent disponibile localmente in modalità non-interattiva per produrre un “triage report” (solo lettura) e lo allega ai log.

## 2) Unit + Timers systemd
- `disk-maintenance-report.service` + `disk-maintenance-report.timer` (learning): es. ogni 1h, report-only.
- `disk-maintenance-cleanup.service` + `disk-maintenance-cleanup.timer`: giornaliero con `RandomizedDelaySec`.
- `disk-maintenance-emergency.service` + `disk-maintenance-emergency.timer`: es. ogni 10–15m controlla soglie e, se scatta, esegue `disk-maintenance emergency`.

## 3) Integrazione “agent headless”
- Preferenza: `codex exec` in modalità read-only/JSON.
- Alternativa: `opencode run --format json`.
- L’agent non deve eseguire comandi arbitrari con sudo; deve solo analizzare output/logs e suggerire prossime azioni.

## 4) Configurazione (consigliata)
- File di config (es. `/etc/disk-maintenance.conf`) con:
  - soglia cleanup (default 85%)
  - soglia emergency (default 95%) e/o minimo free bytes (default 1G)
  - limiti journald (cleanup 200M, emergency 50M)
  - retention coredump (default 14 giorni)
  - snap cleanup enabled + `refresh.retain` target (default 2)
  - docker prune enabled (default true) e volume prune (default false)
  - agent CLI da usare per triage (`codex` vs `opencode`) + modalità output (json/plain)

## 5) Validazione
- Run manuale `disk-maintenance report` e controllo log.
- Simulare soglia (temporaneamente abbassando threshold nel config) e verificare `cleanup`.
- Verificare emergency (threshold molto basso in test) e che il triage agent produca report senza modifiche.
- Verificare log: `journalctl -u disk-maintenance-*.service`.

# Sicurezza / rischi (mitigazioni)
- Evitare `docker system prune -a` e qualunque rimozione immagini “non dangling”.
- Evitare delete indiscriminato in home (`~/.cache`) salvo decisione esplicita.
- Limitare qualunque azione a comandi “bounded” e idempotenti (cache/log/disabled revisions).
- Agent headless: solo lettura/triage (no sudo, no write), output loggato per audit.

# Decisioni (concordate)
- Learning mode: abilitato (report-only orario).
- Cleanup mode: giornaliero, esegue solo se `/` >= 85%.
- Emergency mode: check ogni 10–15m, scatta a `/` >= 95% o free < 1G.
- Docker volumes: volume prune disabilitato (manuale).
- Coredumps: retention 14 giorni.
