resource "aws_ssm_parameter" "vpc_id" {
  name  = "/techchallenge/vpc_id"
  type  = "String"
  value = module.vpc.vpc_id
}

resource "aws_ssm_parameter" "subnets" {
  name  = "/techchallenge/subnets"
  type  = "StringList"
  value = join(",", module.vpc.public_subnets)
}

resource "aws_ssm_parameter" "security_groups" {
  name  = "/techchallenge/security_groups"
  type  = "StringList"
  value = module.eks.node_security_group_id
}
