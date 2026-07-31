terraform {
  backend "s3" {
    bucket       = "proj-terraform-state-bucket-2026"
    key          = "prod/mystatefile/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
    profile      = "default"
  }
}


provider "aws" {
  region  = "eu-west-1"
  profile = "default"
}