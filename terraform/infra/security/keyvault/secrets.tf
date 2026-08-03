resource "random_password" "postgres" {
  length           = 32
  special          = true
  override_special = "!@#-_"
}

resource "random_password" "redis" {
  length           = 32
  special          = true
  override_special = "!@#-_"
}

locals {
  secrets = {
    "postgres-password" = random_password.postgres.result
    "redis-password"    = random_password.redis.result
    # servicebus-connection-string is set by dbs/servicebus stack
  }
}
