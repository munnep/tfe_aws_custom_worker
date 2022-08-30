terraform {
  cloud {
    hostname     = "patrick-tfe9.bg.hashicorp-success.com"
    organization = "test"

    workspaces {
      name = "test-patrick-worker"
    }
  }
}


resource "null_resource" "test" {
  provisioner "local-exec" {
    command = "az --version"
  }
}

