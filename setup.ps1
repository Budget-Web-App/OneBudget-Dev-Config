# https://github.com/hashicorp/vault-guides/blob/master/secrets/dotnet-vault/demo_setup.sh
# Starts the Docker containers defined in the docker-compose.yml file in detached mode and rebuilds them if necessary
docker-compose up -d --build

Do {
    $containersStarted = $true

    $containers = docker ps --format '{{.Names}}'

    foreach ($container in $containers) {
        $inspect = docker inspect --format='{{.State.Status}}' $container

        if ($inspect -ne 'running') {
            $containersStarted = $false
            break
        }
    }

    if (-not $containersStarted) {
        Write-Output "Waiting for Docker containers to start..."
        Start-Sleep -s 5
    }
} while (-not $containersStarted)

Write-Output "All Docker containers are running."

# Enables approle authentication method in Vault
docker exec -d onebudget-vault-1 vault auth enable approle

# Enables two secrets engines in Vault
# `database` type secrets engine at path `projects-api/database`
# `kv` version 2 type secrets engine at path `projects-api/secrets`
docker exec -d onebudget-vault-1 vault secrets enable -path='projects-api/database' database
docker exec -d onebudget-vault-1 vault secrets enable -path='projects-api/secrets' -version=2 kv

# Stores a static key-value pair secret in the `projects-api/secrets` path
docker exec -d onebudget-vault-1 vault kv put projects-api/secrets/static 'password=Testing!123'

# Configures the `projects-api-role` role in the `projects-database` database plugin
# and allows it to access the `projects-api` policy
docker exec -d onebudget-vault-1 vault write projects-api/database/config/projects-database `
    plugin_name=mssql-database-plugin `
    connection_url='postgresql://{{username}}:{{password}}@db:5432/accountsdb' `
    allowed_roles="projects-api-role" `
    username="accountsadmin" `
    password="accountspwd"

# Defines a policy named `projects-api` in Vault by writing the policy in the file `projects-role-policy.hcl`
docker exec -d onebudget-vault-1 vault policy write projects-api ./projects-role-policy.hcl

# Configures the `projects-api-role` role with a set of policies,
# and the `token_ttl`, `token_max_ttl`, `secret_id_num_uses` properties
docker exec -d onebudget-vault-1 vault write auth/approle/role/projects-api-role `
    role_id="projects-api-role" `
    token_policies="projects-api" `
    token_ttl=1h `
    token_max_ttl=2h `
    secret_id_num_uses=5

# Creates secret-id
$output = $(docker exec onebudget-vault-1 vault write -f auth/approle/role/projects-api-role/secret-id)

# BLOCK parses secret-id
$outputList = ($output -split "`n")
$rows = $outputList[2..($outputList.Count - 1)]

$hashtable = @{}

foreach ($row in $rows) {
    $keyValue = $row -split "\s+", 2
    $key = $keyValue[0].Trim()
    $value = $keyValue[1].Trim()
    $hashtable[$key] = $value
}
# BLOCK parses secret-id
Write-Host $hashtable["secret_id"]

# Injects app role id and app role secret into API container
docker exec -e APP_ROLE_ID="projects-api-role" -e APP_ROLE_SECRET="$($hashtable['secret_id'])" onebudget-api-1 env