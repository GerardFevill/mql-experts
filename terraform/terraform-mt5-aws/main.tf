provider "aws" {
  region = var.aws_region
}

# Utiliser le bucket S3 existant pour stocker les scripts MT5
data "aws_s3_bucket" "mt5_scripts_bucket" {
  bucket = "ea-trading-bucket"
}

# Télécharger le script d'installation complet vers S3
resource "aws_s3_object" "install_script" {
  bucket = data.aws_s3_bucket.mt5_scripts_bucket.bucket
  key    = "scripts/install-mt5-full.ps1"
  source = "${path.module}/scripts/core/install-mt5.ps1"
  etag   = filemd5("${path.module}/scripts/core/install-mt5.ps1")
}

# Recherche dynamique de la dernière AMI Windows Server 2019
data "aws_ami" "windows_2019" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2019-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance pour héberger MetaTrader 5
resource "aws_instance" "mt5_instance" {
  ami                    = data.aws_ami.windows_2019.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.mt5_key_pair.key_name
  vpc_security_group_ids = [aws_security_group.mt5_sg.id]
  subnet_id              = aws_subnet.mt5_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.mt5_instance_profile.name
  get_password_data      = true
  
  # Dépendance explicite pour s'assurer que le script est téléchargé vers S3 avant de créer l'instance
  depends_on = [aws_s3_object.install_script]
  
  # Tags pour l'instance
  tags = {
    Name = "MT5-Server"
    MT5_LOGIN = var.mt5_login
    MT5_SERVER = var.mt5_server
    MT5_SETUP = "icmarketssc5setup.exe"
    Environment = var.environment
    Terraform = "true"
  }
  
  # Provisioner pour copier les scripts et exécuter la mise à jour à chaque terraform apply
  # Ces provisioners s'exécuteront après la création complète de l'instance
  provisioner "local-exec" {
    # Afficher un message indiquant que l'instance a été créée avec succès
    command = "echo Instance créée avec succès. ID: ${self.id}, IP: ${self.public_ip}"
  }
  
  # Données utilisateur pour l'initialisation de l'instance - généré dynamiquement à chaque apply
  user_data = <<EOF
<script>
  winrm quickconfig -q
  winrm set winrm/config/winrs @{MaxMemoryPerShellMB="300"}
  winrm set winrm/config @{MaxTimeoutms="1800000"}
  winrm set winrm/config/service @{AllowUnencrypted="true"}
  winrm set winrm/config/service/auth @{Basic="true"}
</script>
<powershell>
# Timestamp généré à chaque apply: ${timestamp()}
${file("${path.module}/scripts/core/bootstrap.ps1")}
</powershell>
EOF

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }
}



# Groupe de sécurité pour l'instance MT5
resource "aws_security_group" "mt5_sg" {
  name        = "mt5-security-group"
  description = "Security group for MT5 instance"
  vpc_id      = aws_vpc.mt5_vpc.id

  # Règle pour le RDP - Temporairement ouvert à toutes les IPs
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Autoriser toutes les IPs
    description = "RDP access - temporary"
  }

  # Règle pour le ping (ICMP)
  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.allowed_ip]
    description = "ICMP ping"
  }

  # Règle pour le trafic sortant
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Outbound traffic"
  }

  tags = {
    Name = "MT5-Security-Group"
  }
}

# Allocation d'une IP élastique
resource "aws_eip" "mt5_eip" {
  instance = aws_instance.mt5_instance.id
  domain   = "vpc"
  
  tags = {
    Name = "MT5-Elastic-IP"
  }
}
