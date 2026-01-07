terraform {
  backend "s3" {
    bucket = "techchallenge-soat12-db-state-db"
    key    = "rds/terraform.tfstate"
    region = "us-east-1"
  }
}
