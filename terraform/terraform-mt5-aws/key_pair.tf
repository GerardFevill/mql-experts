# Génération automatique d'une clé RSA
resource "tls_private_key" "mt5_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Création de la paire de clés AWS
resource "aws_key_pair" "mt5_key_pair" {
  key_name   = var.key_name
  public_key = tls_private_key.mt5_key.public_key_openssh
}

# Sauvegarde de la clé privée dans un fichier local
resource "local_file" "private_key" {
  content         = tls_private_key.mt5_key.private_key_pem
  filename        = "${path.module}/keys/${var.key_name}.pem"
  file_permission = "0400"
}

# Affichage d'un message d'information
output "key_info" {
  value = "La clé privée a été sauvegardée dans ${path.module}/keys/${var.key_name}.pem"
}
