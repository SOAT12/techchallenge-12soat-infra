terraform {
  backend "s3" {
    bucket         = "techchallenge-12soat-terraform-state-bucket"
    key            = "dev/eks-cluster/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "terraform-state-lock-dynamo"
    encrypt        = true
  }
}
