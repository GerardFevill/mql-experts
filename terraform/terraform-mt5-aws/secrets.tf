# Création d'un secret dans AWS Secrets Manager pour stocker le mot de passe MT5
resource "aws_secretsmanager_secret" "mt5_password" {
  name        = "mt5-password-${formatdate("YYYYMMDD-hhmmss", timestamp())}-${uuid()}"  # Nom unique avec timestamp et UUID
  description = "Mot de passe pour le compte MetaTrader 5"
  
  tags = {
    Name = "mt5-password"  # Tag pour faciliter la recherche
    Environment = var.environment
    Terraform   = "true"
  }
}

# Stockage de la valeur du secret
resource "aws_secretsmanager_secret_version" "mt5_password" {
  secret_id     = aws_secretsmanager_secret.mt5_password.id
  secret_string = var.mt5_password
}
