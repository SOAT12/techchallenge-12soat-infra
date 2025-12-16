terraform {
  backend "s3" {
    bucket         = "techchallenge-12soat-tfstate-bucket-us1"
    key            = "dev/eks-cluster/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-dynamo"
    encrypt        = true
  }
}
