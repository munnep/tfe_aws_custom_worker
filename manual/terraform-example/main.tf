terraform {
  cloud {
    hostname = "patrick-tfe5.bg.hashicorp-success.com"
    organization = "test"

    workspaces {
      name = "test-custom-worker"
    }
  }
}


resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "az --version"
  }
}

