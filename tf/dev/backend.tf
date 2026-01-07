terraform {
  backend "s3" {
    bucket = "techchallenge-soat12-db-state-db"
    key = "infra/terraform.tfstate"
    region = "us-east-1"
  }
}
