# dsh-build-lab

Public, secret-free workspace for GitHub-hosted runners.

## What this repo is
- A **sanitized** place to run ordinary CI work on public runners: upstream-tool mirroring with checksum verification, site availability checks, and a secret/PII guard.
- Everything here is reproducible from public sources. No private repository content, no credentials, no personal data.

## What this repo must never contain
- Real names, private e-mail addresses, phone numbers, addresses, or account screenshots.
- Tokens, API keys, cookies, private keys, `.env` files, or credentials of any kind.
- Proxy/relay nodes or subscription links (`ss://`, `vmess://`, `vless://`, `trojan://`, `hysteria://`, `tuic://`).
- Local machine paths, hostnames, IP addresses, or private repository names.

`guard/scan-secrets.sh` enforces this on every push, pull request and on a daily schedule. Findings fail the run.

## Workflows
| file | trigger | purpose |
|---|---|---|
| `.github/workflows/secret-guard.yml` | push, PR, daily 03:17 UTC, manual, `workflow_call` | scans the whole repo **and full git history** for secret/PII patterns |
| `.github/workflows/tools-mirror.yml` | weekly (Mon 04:07 UTC), manual | fetches official upstream releases, verifies SHA-256 against the GitHub asset digest, publishes a verified artifact bundle + manifest |
| `.github/workflows/site-check.yml` | daily 22:17 UTC, manual | checks a public site returns 200 and reports latency |

## Budget rules
- No sub-hourly cron.
- Every job has `timeout-minutes`, every run has an internal deadline.
- `concurrency` groups prevent overlapping runs.
- Retries are bounded (at most 2 retries with backoff).

## Adding a new job — checklist
1. Does it need any credential? If yes → it does not belong here; use a private repo.
2. Does it embed a personal path/hostname/mail? Replace with a generic placeholder or make it configurable via `workflow_dispatch` input.
3. Does the output contain private repo content? Then publish nothing; move the job to the private repo.
4. Run `guard/scan-secrets.sh` locally before pushing:
   ```bash
   bash guard/scan-secrets.sh
   ```
