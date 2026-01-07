output "cluster_name" {
  description = "Nome do cluster EKS."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "O endpoint do servidor da API do Kubernetes."
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Dados do certificado de autoridade do cluster (codificado em base64)."
  value       = module.eks.cluster_certificate_authority_data
}

# output "rds_endpoint" {
#   description = "O endpoint do banco de dados RDS."
#   value       = aws_db_instance.postgres_db.endpoint
# }
#
# output "rds_db_name" {
#   description = "O nome do banco de dados no RDS."
#   value       = aws_db_instance.postgres_db.db_name
# }
#
# output "rds_username" {
#   description = "O nome de usuário do banco de dados RDS."
#   value       = aws_db_instance.postgres_db.username
#   sensitive   = true
# }
#
# output "rds_password" {
#   description = "A senha do banco de dados RDS."
#   value       = aws_db_instance.postgres_db.password
#   sensitive   = true
# }

output "configure_kubectl" {
  description = "Comando para configurar o kubectl para o cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region us-east-1"
}