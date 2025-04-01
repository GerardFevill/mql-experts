# Infrastructure AWS pour MetaTrader 5 avec EA MQL5

Ce projet Terraform déploie une infrastructure AWS optimisée pour héberger un Expert Advisor MQL5 sur MetaTrader 5, de manière sécurisée, automatisée et économique.

## Structure du projet

Le projet est organisé en plusieurs étapes distinctes :

### 🟩 Étape 1 : EC2 Instance (Windows)
- Instance EC2 Windows Server 2019 (type t3.micro) dans la région eu-west-2 (Londres)
- Disque gp3 de 30 Go
- IP publique élastique
- Port RDP 3389 ouvert avec restrictions d'accès
- Configuration optimisée pour un coût minimal

## Prérequis

- [Terraform](https://www.terraform.io/downloads.html) v1.0.0+
- Compte AWS avec les permissions nécessaires
- Paire de clés AWS pour l'accès à l'instance

## Configuration

1. Copiez le fichier `terraform.tfvars.example` en `terraform.tfvars`
2. Modifiez le fichier `terraform.tfvars` avec vos propres valeurs

## Déploiement

```bash
# Initialiser Terraform
terraform init

# Vérifier le plan de déploiement
terraform plan

# Déployer l'infrastructure
terraform apply

# Pour détruire l'infrastructure
terraform destroy
```

## Coûts estimés

- Instance EC2 t3.micro : ~$10/mois
- Volume EBS gp3 30 Go : ~$3/mois
- IP Élastique (attachée à une instance) : gratuit

Coût total estimé : ~$13/mois

## Sécurité

Pour renforcer la sécurité :
- Limitez l'accès RDP à votre adresse IP uniquement dans la variable `allowed_ip`
- Utilisez un mot de passe Windows fort
- Considérez l'utilisation d'un VPN pour l'accès à l'instance
