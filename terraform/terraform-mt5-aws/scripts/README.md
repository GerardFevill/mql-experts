# Scripts d'initialisation Windows pour MT5

Ce répertoire contient des scripts PowerShell modulaires pour l'initialisation et la configuration des instances Windows Server déployées avec Terraform pour héberger MetaTrader 5. Il inclut également des scripts pour la mise à jour et la maintenance des instances existantes.

## Structure des fichiers

```
scripts/
│── core/                         # Scripts principaux d'initialisation
│   │── Install-WindowsServer.ps1  # Script principal d'initialisation
│   └── update-mt5.ps1            # Script de mise à jour pour MT5
│── modules/                      # Modules PowerShell réutilisables
│   │── CloudWatch.psm1           # Module pour CloudWatch
│   │── Firewall.psm1             # Module pour le pare-feu
│   │── Logging.psm1              # Module pour la journalisation
│   │── MT5.psm1                  # Module pour MetaTrader 5
│   │── Optimization.psm1         # Module pour l'optimisation
│   └── Security.psm1             # Module pour la sécurité
│── utils/                        # Scripts utilitaires
│   │── copy-scripts.ps1          # Script pour copier les scripts vers l'instance
│   │── get-admin-password.ps1    # Script pour récupérer le mot de passe administrateur
│   └── generate_rsa_key.ps1      # Utilitaire pour générer des clés RSA
└── README.md                     # Ce fichier
```

## Utilisation

Le script principal `core/Install-WindowsServer.ps1` est conçu pour être exécuté au démarrage de l'instance EC2 via les données utilisateur. Il importe automatiquement tous les modules nécessaires et exécute les différentes étapes d'initialisation.

Pour les instances existantes, utilisez le script `core/update-mt5.ps1` pour mettre à jour la configuration de MT5 sans avoir à recréer l'instance.

### Exécution manuelle

Pour exécuter le script manuellement sur une instance Windows :

```powershell
# Exécuter le script avec des privilèges administratifs
powershell -ExecutionPolicy Bypass -File C:\path\to\scripts\core\Install-WindowsServer.ps1
```

### Intégration avec Terraform

Dans votre fichier Terraform, utilisez le script dans la section `user_data` :

```hcl
resource "aws_instance" "mt5_instance" {
  # ...
  user_data = <<EOF
<powershell>
${file("${path.module}/scripts/core/Install-WindowsServer.ps1")}
</powershell>
EOF
}
```

### Workflow complet pour les mises à jour

1. Déployer l'instance avec Terraform :
   ```bash
   terraform apply
   ```

2. Récupérer le mot de passe administrateur et l'adresse IP :
   ```powershell
   ./scripts/get-admin-password.ps1 -InstanceId i-0123456789abcdef0 -KeyPath ./my-key.pem -Region eu-west-1
   ```

3. Copier les scripts vers l'instance :
   ```powershell
   ./scripts/copy-scripts.ps1 -InstanceIP 1.2.3.4 -KeyPath ./my-key.pem
   ```

4. Se connecter à l'instance via RDP et exécuter le script de mise à jour :
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\MT5\scripts\core\update-mt5.ps1
   ```

Ou utiliser le provisioner dans Terraform pour exécuter automatiquement le script de mise à jour lors des `terraform apply` suivants.

## Modules

### Logging.psm1

Fournit des fonctions pour la journalisation standardisée :
- `Write-Log` : Écrit un message dans le fichier journal
- `Initialize-LogFile` : Initialise le fichier journal

### Security.psm1

Configure les paramètres de sécurité :
- `Disable-IEESC` : Désactive IE Enhanced Security Configuration
- `Set-SecuritySettings` : Configure les paramètres de sécurité Windows

### Optimization.psm1

Optimise les performances de Windows Server :
- `Optimize-WindowsServer` : Désactive les services inutiles et optimise les performances
- `Clear-TempFiles` : Nettoie les fichiers temporaires

### Firewall.psm1

Configure le pare-feu Windows :
- `Configure-Firewall` : Configure les règles de base du pare-feu
- `Open-FirewallPort` : Ouvre un port spécifique dans le pare-feu

### CloudWatch.psm1

Installe et configure l'agent CloudWatch :
- `Install-CloudWatchAgent` : Télécharge, installe et configure l'agent CloudWatch
- `Get-CloudWatchConfig` : Génère la configuration pour l'agent CloudWatch

## Journalisation

Tous les scripts écrivent des journaux détaillés dans `C:\Windows\Temp\init_windows.log`. Ces journaux sont également envoyés à CloudWatch une fois l'agent installé.

## Marqueur de complétion

Une fois l'exécution terminée avec succès, un fichier marqueur est créé à `C:\Windows\Temp\init_complete.marker`.
