# --- GitHub OIDC Provider ---

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# --- Deployment Role for GitHub Actions ---

resource "aws_iam_role" "github_actions_app_deploy" {
  name = "GitHubActionsAppDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:SOAT12/techchallenge-12SOAT*:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Permissions for the deployment role (ECR, EKS access)
resource "aws_iam_role_policy_attachment" "github_actions_ecr_full" {
  role       = aws_iam_role.github_actions_app_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy_attachment" "github_actions_eks_cluster" {
  role       = aws_iam_role.github_actions_app_deploy.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  cluster_version = "1.30"

  kms_key_administrators = [
    "arn:aws:iam::258531703731:role/GitHubActionsInfraRole",
    "arn:aws:iam::258531703731:user/caiohnrq",
    aws_iam_role.github_actions_app_deploy.arn
  ]

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  eks_managed_node_groups = {
    main = {
      min_size                    = 1
      max_size                    = 3
      desired_size                = 2
      instance_types              = ["t3.small"]
      associate_public_ip_address = true
      iam_role_additional_policies = {
        ecr_read_only = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      }
    }
  }

  manage_aws_auth_configmap = true

  aws_auth_roles = [
    {
      rolearn  = aws_iam_role.github_actions_app_deploy.arn
      username = "github-actions-app-deploy"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::258531703731:user/caiohnrq"
      username = "caiohnrq"
      groups   = ["system:masters"]
    }
  ]

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${module.eks.cluster_name}-aws-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  name   = "${module.eks.cluster_name}-aws-load-balancer-controller-policy"
  policy = file("${path.module}/iam_policy_load_balancer_controller.json")
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
  role       = aws_iam_role.aws_load_balancer_controller.name
}



resource "aws_secretsmanager_secret" "techchallenge_secrets" {
  name                    = "techchallenge-credentials"
  recovery_window_in_days = 0 # For quick deletion/recreation in dev
}

resource "aws_secretsmanager_secret_version" "techchallenge_secrets_version" {
  secret_id = aws_secretsmanager_secret.techchallenge_secrets.id
  secret_string = jsonencode({
    # Placeholder for the secrets that will be managed manually or via another process
    MERCADO_PAGO_ACCESS_TOKEN = "placeholder"
    MONGODB_URI               = "placeholder"
  })

  lifecycle {
    ignore_changes = [secret_string] # Allow manual updates without Terraform overwriting
  }
}

resource "aws_iam_policy" "secrets_manager_read_policy" {
  name = "${module.eks.cluster_name}-secrets-manager-read-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = aws_secretsmanager_secret.techchallenge_secrets.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "secrets_manager_read_attachment" {
  policy_arn = aws_iam_policy.secrets_manager_read_policy.arn
  role       = module.eks.eks_managed_node_groups["main"].iam_role_name
}

resource "aws_iam_role" "techchallenge_app_role" {
  name = "${module.eks.cluster_name}-techchallenge-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(module.eks.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")}:sub" = "system:serviceaccount:techchallenge:default"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "techchallenge_app_secrets_read_attachment" {
  policy_arn = aws_iam_policy.secrets_manager_read_policy.arn
  role       = aws_iam_role.techchallenge_app_role.name
}