data "terraform_remote_state" "identity" {
  backend = "local"

  config = {
    path = "${path.module}/../security/identity/terraform.tfstate"
  }
}
