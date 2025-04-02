variable "aws_region" {
  description = "Région AWS où déployer l'infrastructure"
  type        = string
  default     = "eu-west-2"  # Londres
}

variable "windows_ami" {
  description = "AMI Windows Server 2019 pour la région spécifiée"
  type        = string
  # AMI Windows Server 2019 Base pour eu-west-2 (Londres)
  # Cette AMI est mise à jour régulièrement par AWS
  default     = "ami-0d3c032f5934e1b41"  # Windows Server 2019 Base pour eu-west-2 (mise à jour)
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Nom de la paire de clés pour l'accès SSH"
  type        = string
}

variable "allowed_ip" {
  description = "Adresse IP autorisée à se connecter en RDP (format CIDR)"
  type        = string
  default     = "0.0.0.0/0"  # Par défaut, toutes les IPs - à restreindre en production
}

# Variables pour MetaTrader 5
variable "mt5_login" {
  description = "Identifiant de connexion MetaTrader 5"
  type        = string
}

variable "mt5_password" {
  description = "Mot de passe MetaTrader 5 (sera stocké dans AWS Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "mt5_server" {
  description = "Serveur MetaTrader 5 (ex: ICMarkets-Live, FXCM-Demo, etc.)"
  type        = string
}
