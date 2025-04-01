provider "aws" {
  region = var.aws_region
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
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.mt5_sg.id]
  subnet_id              = aws_subnet.mt5_subnet.id
  iam_instance_profile   = aws_iam_instance_profile.mt5_instance_profile.name
  
  # Données utilisateur pour l'initialisation de l'instance
  user_data = <<EOF
<script>
  winrm quickconfig -q
  winrm set winrm/config/winrs @{MaxMemoryPerShellMB="300"}
  winrm set winrm/config @{MaxTimeoutms="1800000"}
  winrm set winrm/config/service @{AllowUnencrypted="true"}
  winrm set winrm/config/service/auth @{Basic="true"}
</script>
<powershell>
# Activer le journal des événements pour les données utilisateur
$logFile = "C:\Windows\Temp\user_data_execution.log"
"Démarrage de l'exécution des données utilisateur à $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logFile

try {
  # Exécuter le script d'initialisation
  ${file("${path.module}/scripts/init_windows.ps1")}
  "Script d'initialisation exécuté avec succès" | Out-File -FilePath $logFile -Append
} catch {
  "ERREUR lors de l'exécution du script d'initialisation: $_" | Out-File -FilePath $logFile -Append
}
</powershell>
EOF

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "MT5-EA-Instance"
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
