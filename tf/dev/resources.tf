# --- ECR ---
resource "aws_ecr_repository" "billing_api" {
  name                 = "billing-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "techchallenge-billing"
    Environment = local.environment
  }
}

resource "aws_ecr_repository" "stock_api" {
  name                 = "stock-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = "techchallenge-stock"
    Environment = local.environment
  }
}

# --- Messaging (SQS/SNS) ---

resource "aws_sqs_queue" "payment_notifications" {
  name                      = "payment-notifications-queue"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 20 # Enable long polling

  tags = {
    Environment = local.environment
    Project     = "techchallenge-billing"
  }
}

resource "aws_sqs_queue" "stock_add_event" {
  name                      = "stock-add-event"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 20

  tags = {
    Environment = local.environment
    Project     = "techchallenge-shared"
  }
}

resource "aws_sqs_queue" "stock_remove_event" {
  name                      = "stock-remove-event"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 20

  tags = {
    Environment = local.environment
    Project     = "techchallenge-shared"
  }
}

resource "aws_sqs_queue" "os_status_update_event" {
  name                      = "os-status-update-event"
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 20

  tags = {
    Environment = local.environment
    Project     = "techchallenge-shared"
  }
}

resource "aws_sns_topic" "payment_approved" {
  name = "payment-approved-topic"

  tags = {
    Environment = local.environment
    Project     = "techchallenge-billing"
  }
}

resource "aws_sns_topic" "payment_failed" {
  name = "payment-failed-topic"

  tags = {
    Environment = local.environment
    Project     = "techchallenge-billing"
  }
}

# --- API Gateway ---

# Creates an HTTP API Gateway to act as an HTTPS proxy for the Kubernetes Load Balancer
resource "aws_apigatewayv2_api" "webhook_proxy" {
  name          = "billing-webhook-proxy"
  protocol_type = "HTTP"
  description   = "Proxy for Mercado Pago Webhooks to Kubernetes ELB"
}

# Configures the integration to forward requests to the Classic Load Balancer
resource "aws_apigatewayv2_integration" "elb_integration" {
  api_id           = aws_apigatewayv2_api.webhook_proxy.id
  integration_type = "HTTP_PROXY"
  # We use the {proxy} path variable to forward the exact path requested
  integration_uri    = "http://k8s-default-billinga-9b5436fa5f-deaf60452d417223.elb.us-east-1.amazonaws.com/{proxy}"
  integration_method = "ANY"
  connection_type    = "INTERNET"
}

# Creates a catch-all route that sends all traffic to the integration
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.webhook_proxy.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.elb_integration.id}"
}

# Creates a default stage that automatically deploys changes
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.webhook_proxy.id
  name        = "$default"
  auto_deploy = true
}

# --- Load Balancer to Node Connectivity ---

resource "aws_security_group_rule" "allow_lb_to_nodes" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = "sg-038e460c976e2fae2" # The Managed LB SG we found
  description              = "Allow traffic from Managed Load Balancer to EKS nodes"
}

# --- IAM IRSA for Billing ---

module "billing_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "billing-api-irsa"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:billing-sa"]
    }
  }

  tags = {
    Environment = local.environment
    Project     = "techchallenge-billing"
  }
}

# --- IAM IRSA for Stock ---

module "stock_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "stock-api-irsa"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:stock-sa"]
    }
  }

  tags = {
    Environment = local.environment
    Project     = "techchallenge-stock"
  }
}

# Policy allowing the Billing API to interact with specific SQS queues and SNS topics
resource "aws_iam_policy" "billing_messaging_policy" {
  name        = "BillingMessagingPolicy"
  description = "Allows Billing API to publish to SNS and consume from SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:SendMessage"
        ],
        Resource = aws_sqs_queue.payment_notifications.arn
      },
      {
        Effect = "Allow",
        Action = [
          "sns:Publish"
        ],
        Resource = [
          aws_sns_topic.payment_approved.arn,
          aws_sns_topic.payment_failed.arn
        ]
      }
    ]
  })
}

# Policy allowing the Stock API to interact with specific SQS queues and SNS topics
resource "aws_iam_policy" "stock_messaging_policy" {
  name        = "StockMessagingPolicy"
  description = "Allows Stock API to publish and consume from SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          aws_sqs_queue.stock_add_event.arn,
          aws_sqs_queue.stock_remove_event.arn,
          aws_sqs_queue.os_status_update_event.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "billing_irsa_messaging" {
  role       = module.billing_irsa_role.iam_role_name
  policy_arn = aws_iam_policy.billing_messaging_policy.arn
}

resource "aws_iam_role_policy_attachment" "stock_irsa_messaging" {
  role       = module.stock_irsa_role.iam_role_name
  policy_arn = aws_iam_policy.stock_messaging_policy.arn
}
