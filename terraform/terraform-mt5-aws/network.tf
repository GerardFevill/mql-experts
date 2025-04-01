# Création d'un VPC pour notre infrastructure
resource "aws_vpc" "mt5_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "MT5-VPC"
  }
}

# Création d'un sous-réseau public
resource "aws_subnet" "mt5_subnet" {
  vpc_id                  = aws_vpc.mt5_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "MT5-Subnet-Public"
  }
}

# Création d'une passerelle Internet
resource "aws_internet_gateway" "mt5_igw" {
  vpc_id = aws_vpc.mt5_vpc.id

  tags = {
    Name = "MT5-Internet-Gateway"
  }
}

# Création d'une table de routage
resource "aws_route_table" "mt5_route_table" {
  vpc_id = aws_vpc.mt5_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mt5_igw.id
  }

  tags = {
    Name = "MT5-Route-Table"
  }
}

# Association de la table de routage au sous-réseau
resource "aws_route_table_association" "mt5_route_assoc" {
  subnet_id      = aws_subnet.mt5_subnet.id
  route_table_id = aws_route_table.mt5_route_table.id
}
