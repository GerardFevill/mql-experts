output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.mt5_instance.id
}

output "public_ip" {
  description = "Adresse IP publique de l'instance"
  value       = aws_eip.mt5_eip.public_ip
}

output "rdp_connection" {
  description = "Commande pour se connecter en RDP"
  value       = "mstsc /v:${aws_eip.mt5_eip.public_ip}"
}

# Information sur le groupe de logs CloudWatch
output "cloudwatch_log_group" {
  value       = aws_cloudwatch_log_group.mt5_logs.name
  description = "Nom du groupe de logs CloudWatch pour l'instance MT5"
}

# Commande pour déployer les scripts sur l'instance
output "deploy_command" {
  description = "Commande pour déployer les scripts sur l'instance"
  value       = "powershell -ExecutionPolicy Bypass -File .\\scripts\\utils\\deploy-to-instance.ps1 -InstanceId ${aws_instance.mt5_instance.id} -PublicIp ${aws_eip.mt5_eip.public_ip} -KeyPath .\\keys\\mt5-key.pem"
}

# URL de la console CloudWatch pour accéder aux logs
output "cloudwatch_logs_console_url" {
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#logsV2:log-groups/log-group/${replace(aws_cloudwatch_log_group.mt5_logs.name, "/", "$252F")}"
  description = "URL de la console CloudWatch pour accéder aux logs de l'instance MT5"
}
