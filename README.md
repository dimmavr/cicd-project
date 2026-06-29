# Self-Hosted CI/CD & Observability Platform
 
A complete, self-hosted CI/CD pipeline with integrated monitoring, alerting, and centralized logging — built from scratch on local VMs without managed cloud services. Every component is installed and configured manually (binaries, systemd services, dedicated users) to demonstrate deep understanding of how the tooling actually works under the hood.
 
This project takes code from a `git push` all the way to a running, monitored, self-healing service on a separate node — with automated rollback if a deployment fails.
 
## Architecture
 
```
┌─────────────────────────────────────┐      ┌──────────────────────────────────┐
│  ci-host  (192.168.56.10)            │      │  app-node  (192.168.56.11)       │
│  "control plane"                     │      │  "production node"               │
│                                      │      │                                  │
│  • Gitea          :3000  (git)       │      │  • webapp.sh      :8000          │
│  • Jenkins        :8080  (CI/CD)     │      │    (systemd service, user webapp)│
│  • Prometheus     :9090  (metrics)   │      │  • node_exporter  :9100          │
│  • Blackbox exp.  :9115  (probing)   │      │    (CPU / RAM / disk metrics)    │
│  • Alertmanager   :9093  (alerts)    │      │  • Promtail       :9080          │
│  • Loki           :3100  (logs)      │      │    (ships journal logs → Loki)   │
│  • Grafana        :3001  (dashboards)│      │                                  │
└─────────────────────────────────────┘      └──────────────────────────────────┘
        host-only network 192.168.56.0/24
```
 
### Deployment flow
 
```
git push → Gitea → webhook → Jenkins
                                 │
                                 ├─ Build stage
                                 └─ Deploy stage (deploy.sh)
                                        │ scp webapp.sh → app-node:/tmp
                                        └─ ssh → sudo install.sh
                                                    ├─ timestamped backup
                                                    ├─ install new version
                                                    ├─ systemctl restart
                                                    ├─ health check (curl)
                                                    └─ rollback on failure
```
 
## Tech stack
 
| Layer | Tools |
|-------|-------|
| Source control | Gitea (self-hosted) |
| CI/CD | Jenkins, Declarative Pipeline (Jenkinsfile) |
| Deployment | Bash, SSH key auth, scp, scoped sudoers |
| Runtime | systemd services, dedicated low-privilege users |
| Metrics | Prometheus, node_exporter, blackbox_exporter |
| Visualization | Grafana |
| Alerting | Alertmanager |
| Logging | Loki, Promtail |
| Infrastructure | Ubuntu 24.04 VMs, host-only networking |
 
## How it works
 
### CI/CD pipeline
A push to the Gitea repository triggers a Jenkins pipeline via webhook. The pipeline checks out the code and runs a two-stage Declarative Pipeline: a build stage and a deploy stage. The deploy stage runs `deploy.sh`, which ships the application to the production node and triggers a remote install.
 
### Two-script deployment architecture
Deployment is split between two scripts with a clear separation of responsibilities:
 
- **`deploy.sh`** (orchestrator) — runs on ci-host as the `jenkins` user. Ships `webapp.sh` to the app-node via `scp` and triggers the installer over SSH.
- **`install.sh`** (worker) — runs on app-node as root, but **only** via a tightly-scoped `sudoers` rule that permits the `deploy` user to run this one script and nothing else. It performs a timestamped backup, installs the new version, restarts the service, runs a health check, and **automatically rolls back** to the last known-good version if the health check fails.
### Security model (least privilege throughout)
- Every service runs as its own dedicated, non-login system user.
- The CI system connects to the production node via SSH key authentication — no passwords.
- The `deploy` user has a single `NOPASSWD` sudoers entry scoped to `install.sh` only — it cannot run arbitrary commands as root.
- The installer script is owned by root and not writable by the deploy user, so the privilege boundary cannot be bypassed.
### Monitoring & alerting
Prometheus scrapes two kinds of metrics: blackbox probes (is the app responding? how fast?) and node_exporter system metrics (CPU, memory, disk). Grafana visualizes both. An Alertmanager alert rule (`WebappDown`) fires when the application stops responding for over a minute, and resolves automatically when it recovers — the full incident lifecycle was tested by stopping and restarting the service.
 
### Centralized logging
Promtail reads the systemd journal on the app-node and ships logs to Loki on the control plane. Logs are queryable in Grafana alongside the metrics, so a single dashboard shows both *that* something broke (metrics/alert) and *why* (logs).
 
## Repository layout
 
```
.
├── Jenkinsfile               # CI/CD pipeline definition
├── scripts/
│   ├── deploy.sh             # orchestrator (runs on ci-host)
│   ├── install.sh            # worker (runs on app-node)
│   └── webapp.sh             # the demo application (bash + netcat web server)
├── config/
│   ├── prometheus/           # prometheus.yml + alert rules
│   ├── alertmanager/         # alertmanager.yml
│   ├── blackbox/             # blackbox.yml
│   ├── loki/                 # loki-config.yml
│   └── promtail/             # promtail-config.yml
└── systemd/                  # all service unit files
```
 
## Engineering notes & problems solved
 
Real problems encountered and debugged during the build — the kind of operational detail that doesn't show up in a tutorial:
 
- **Netcat connection handling** — the bash/netcat web server hung the health-check `curl` indefinitely because connections were never closed. Fixed with the `nc -N` flag, which shuts down the socket after the response. This was caught precisely because the rollback path was tested rather than trusted.
- **Health check timeouts** — added `curl --max-time` so a stuck service fails the health check instead of blocking the deployment forever.
- **Gitea SSRF protection** — Gitea blocks webhooks to private IP ranges by default; resolved by configuring `ALLOWED_HOST_LIST`.
- **Jenkins notifyCommit auth** — newer Jenkins Git plugin versions require an access token on the `notifyCommit` endpoint; the webhook URL needed the token appended.
- **Expired apt repository GPG key** — the Jenkins repo key had expired and was rotated upstream; required downloading the current signing key.
- **Binary architecture** — an early download grabbed a `darwin` (macOS) build instead of `linux-amd64`; a reminder to always verify the platform suffix.
- **Port conflict** — Grafana defaults to port 3000, which Gitea already occupied; moved Grafana to 3001.
- **systemd journal permissions** — Promtail needs membership in the `systemd-journal` and `adm` groups to read the journal.
- **sudoers permissions** — files in `/etc/sudoers.d/` must be mode `0440` or they are ignored; validated with `visudo -c`.
## A note on tool currency
 
Promtail reached end-of-life in March 2026; for a new production deployment, Grafana Alloy would be the appropriate successor. Promtail was chosen here for its simplicity and because it remains widely deployed in existing systems.
 
## Status
 
All six phases complete: source control, CI/CD pipeline, automated deployment with rollback, metrics monitoring, alerting, and centralized logging — all tested end-to-end.
