# -----------------------------------------------------------------------------
# 1. ECR Repository (Onde a imagem da Lambda será armazenada)
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "auth_repo" {
  name                 = "techchallenge-auth-lambda"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "techchallenge-auth-repo"
  }
}

# -----------------------------------------------------------------------------
# 2. IAM Role (Permissões da Lambda)
# -----------------------------------------------------------------------------
resource "aws_iam_role" "auth_lambda_role" {
  name = "techchallenge_auth_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "auth_lambda_basic_execution" {
  role       = aws_iam_role.auth_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "auth_lambda_vpc_access" {
  role       = aws_iam_role.auth_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# -----------------------------------------------------------------------------
# 3. Security Groups (Segurança de Rede)
# -----------------------------------------------------------------------------
resource "aws_security_group" "auth_lambda_sg" {
  name        = "techchallenge-auth-lambda-sg"
  description = "Security group for Auth Lambda"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "techchallenge-auth-lambda-sg"
  }
}

# Adiciona permissão no SG do RDS para aceitar a Lambda
resource "aws_security_group_rule" "allow_lambda_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds_sg.id
  source_security_group_id = aws_security_group.auth_lambda_sg.id
}

# -----------------------------------------------------------------------------
# 4. API Gateway (HTTP API - Entrypoint da Aplicação)
# -----------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "auth_api" {
  name          = "techchallenge-auth-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.auth_api.id
  name        = "$default"
  auto_deploy = true
}

# -----------------------------------------------------------------------------
# 4. Lambda Function & Integração
# -----------------------------------------------------------------------------
# ATENÇÃO: Este bloco só deve ser descomentado APÓS o primeiro push da imagem
# para o ECR criado acima. Caso contrário, o Terraform falhará ao não encontrar a imagem.
# -----------------------------------------------------------------------------


resource "aws_lambda_function" "auth" {
  function_name = "techchallenge-auth"
  role          = aws_iam_role.auth_lambda_role.arn
  package_type  = "Image"

  # A URI da imagem deve vir do seu repositório ECR
  image_uri     = "${aws_ecr_repository.auth_repo.repository_url}:latest"

  timeout     = 30
  memory_size = 512

  vpc_config {
    subnet_ids         = module.vpc.private_subnets
    security_group_ids = [aws_security_group.auth_lambda_sg.id]
  }

  environment {
    variables = {
      SPRING_PROFILES_ACTIVE = "prod"
      DB_HOST               = aws_db_instance.postgres_db.address
      DB_NAME               = aws_db_instance.postgres_db.db_name
      DB_USER               = aws_db_instance.postgres_db.username
      DB_PASSWORD           = aws_db_instance.postgres_db.password
      JWT_SECRET            = "sua-chave-secreta-aqui" # Idealmente usar Secrets Manager
    }
  }
}

resource "aws_apigatewayv2_integration" "auth_integration" {
  api_id           = aws_apigatewayv2_api.auth_api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Lambda Auth Integration"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.auth.invoke_arn

  payload_format_version = "1.0" # Compatibilidade com eventos REST
}

resource "aws_apigatewayv2_route" "auth_route" {
  api_id    = aws_apigatewayv2_api.auth_api.id
  route_key = "POST /token" # Ajuste a rota conforme sua aplicação
  target    = "integrations/${aws_apigatewayv2_integration.auth_integration.id}"
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth_api.execution_arn}/* / *"
}


# Outputs para ajudar no CI/CD
output "ecr_repository_url" {
  value = aws_ecr_repository.auth_repo.repository_url
}

output "api_gateway_endpoint" {
  value = aws_apigatewayv2_api.auth_api.api_endpoint
}
