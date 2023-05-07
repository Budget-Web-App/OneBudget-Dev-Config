FROM hashicorp/vault:latest

COPY vault.hcl /vault/config/vault.hcl

CMD ["vault", "server", "-config", "/vault/config/vault.hcl"]
