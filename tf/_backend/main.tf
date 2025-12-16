# Define o provider da AWS
provider "aws" {
  region = "us-east-1"
}

# Cria o bucket S3 para armazenar o arquivo de estado
resource "aws_s3_bucket" "tfstate" {
  bucket = "techchallenge-12soat-terraform-state-bucket"

  # Impede a destruição acidental do bucket
  lifecycle {
    # prevent_destroy = true
  }
}

# Habilita o versionamento para segurança
resource "aws_s3_bucket_versioning" "tfstate_versioning" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Habilita a criptografia do lado do servidor
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_sse" {
  bucket = aws_s3_bucket.tfstate.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Cria a tabela DynamoDB para o 'state locking'
resource "aws_dynamodb_table" "tflock" {
  name         = "terraform-state-lock-dynamo"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
