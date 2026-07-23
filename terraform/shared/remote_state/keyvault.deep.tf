data "terraform_remote_state" "keyvault" {
  backend = "local"

  config = {
    path = "${path.module}/../../security/keyvault/terraform.tfstate"
  }
}
