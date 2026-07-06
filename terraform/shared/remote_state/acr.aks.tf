data "terraform_remote_state" "acr" {
  backend = "local"

  config = {
    path = "${path.module}/../security/acr/terraform.tfstate"
  }
}
