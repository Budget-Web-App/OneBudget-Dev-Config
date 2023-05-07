# Vault Configuration File
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address = "0.0.0.0:8204"
  #tls_cert_file = "/path/to/full-chain.pem"
  #tls_key_file  = "/path/to/private-key.pem"
  tls_disable = true
}

# Enable the cubbyhole secret engine
#secrets {
#  engine = "cubbyhole"
#}

# Other Vault configurations can be added below
ui            = true
cluster_addr  = "https://127.0.0.1:8201"
api_addr      = "https://127.0.0.1:8202"
disable_mlock = true

#telemetry {
#  statsite_address = "127.0.0.1:8125"
#  disable_hostname = true
#}