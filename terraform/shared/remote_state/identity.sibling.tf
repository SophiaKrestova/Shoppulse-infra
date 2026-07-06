data "terraform_remote_state" "identity" {
  backend = "local"

  config = {
    path = "${path.module}/../identity/terraform.tfstate"
  }
}
