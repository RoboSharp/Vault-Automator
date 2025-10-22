
# Vault Automator

Automates HashiCorp Vault setup for homelab and self-hosted environments. Just run with Docker Compose and your Vault server will be initialized and unsealed automatically. No manual key handling required.

## What It Does

- Initializes Vault on first run
- Unseals Vault automatically if it becomes sealed
- Stores unseal keys and root token in a local file (`./unseal/vault_unseal_keys.json`)
- Monitors Vault status and logs activity

## Quick Start

1. Clone this repo and enter the directory:
   ```bash
   git clone <repository-url>
   cd vault-automator
   ```
2. Start Vault and the automator:
   ```bash
   docker compose up -d
   ```
3. Open the Vault UI at [http://localhost:8200](http://localhost:8200)

Unseal keys and root token will be saved in `./unseal/vault_unseal_keys.json` after first run.

## Configuration

You can tweak behavior with environment variables in `docker-compose.yml`:

| Variable         | Default                              | Description                       |
|------------------|--------------------------------------|-----------------------------------|
| VAULT_ADDR       | http://vault:8200                    | Vault server address              |
| UNSEAL_FILE      | /unseal/vault_unseal_keys.json        | Where to save keys                |
| VAULT_SHARES     | 1                                    | Number of key shares              |
| VAULT_THRESHOLD  | 1                                    | Keys needed to unseal             |
| POLL_INTERVAL    | 5                                    | Status check interval (seconds)   |
| TIMEOUT_SECONDS  | 5                                    | Vault status timeout (seconds)    |

## File Layout

```
vault-automator/
├── docker-compose.yml
├── Dockerfile
├── src/
│   └── vault-automator.sh
├── unseal/
│   └── vault_unseal_keys.json
├── vault-data/
└── example/
    └── docker-compose.yml
```

## Building Manually

```bash
docker build -t vault-automator .
docker compose up --build
```

## Logs

See what's happening:
```bash
docker compose logs -f vault-automator
docker compose logs -f vault
```

## Troubleshooting

- If Vault isn't reachable, check that both containers are running
- If keys aren't saved, check permissions on the `unseal` folder
- For most homelab setups, defaults should work out of the box

## License

MIT (see LICENSE file)