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

resource "random_password" "servicebus" {
  length  = 64
  special = false
}

locals {
  secrets = {
    "postgres-password"            = random_password.postgres.result
    "redis-password"               = random_password.redis.result
    "servicebus-connection-string" = random_password.servicebus.result
  }
}
