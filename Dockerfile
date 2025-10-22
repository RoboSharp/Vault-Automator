FROM hashicorp/vault:latest

LABEL maintainer="RoboSharp Vault-Automator"
LABEL org.opencontainers.image.title="Vault-Automator"
LABEL org.opencontainers.image.description="Automates initialization and unsealing of HashiCorp Vault for homelab and self-hosted setups."
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/RoboSharp/Vault-Automator"

RUN apk add --no-cache jq bash
COPY src/vault-automator.sh /vault-automator.sh
RUN chmod a+x /vault-automator.sh

CMD ["/bin/bash", "/vault-automator.sh"]