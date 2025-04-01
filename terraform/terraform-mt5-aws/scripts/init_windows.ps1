# Script d'initialisation pour l'instance Windows Server
# Ce script sera exécuté lors du premier démarrage de l'instance

# Démarrer la journalisation
$logFile = "C:\Windows\Temp\init_windows.log"
"Démarrage du script d'initialisation à $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File -FilePath $logFile

# Configuration de l'exécution des scripts PowerShell
try {
    Set-ExecutionPolicy Unrestricted -Force
    "ExecutionPolicy configurée en Unrestricted" | Out-File -FilePath $logFile -Append
} catch {
    "ERREUR lors de la configuration de ExecutionPolicy: $_" | Out-File -FilePath $logFile -Append
}

# Désactiver IE Enhanced Security Configuration
function Disable-IEESC {
    try {
        $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
        "IE Enhanced Security Configuration (ESC) désactivé." | Out-File -FilePath $logFile -Append
    } catch {
        "ERREUR lors de la désactivation de IE ESC: $_" | Out-File -FilePath $logFile -Append
    }
}
Disable-IEESC

# Optimisations pour réduire l'utilisation des ressources
function Optimize-WindowsServer {
    try {
        # Désactiver les services inutiles
        $servicesToDisable = @(
            "DiagTrack",                     # Service de diagnostic
            "WSearch",                       # Windows Search
            "wuauserv",                      # Windows Update
            "SysMain",                       # SuperFetch
            "WerSvc"                         # Windows Error Reporting
        )

        foreach ($service in $servicesToDisable) {
            if (Get-Service $service -ErrorAction SilentlyContinue) {
                Stop-Service -Name $service -Force -ErrorAction SilentlyContinue
                Set-Service -Name $service -StartupType Disabled -ErrorAction SilentlyContinue
                "Service $service désactivé." | Out-File -FilePath $logFile -Append
            }
        }

        # Désactiver les tâches planifiées inutiles
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\ProgramDataUpdater" -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" -ErrorAction SilentlyContinue
        "Tâches planifiées inutiles désactivées." | Out-File -FilePath $logFile -Append
        
        # Désactiver les effets visuels pour améliorer les performances
        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (!(Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
        Set-ItemProperty -Path $path -Name "VisualFXSetting" -Value 2
        
        "Optimisations Windows Server terminées." | Out-File -FilePath $logFile -Append
    } catch {
        "ERREUR lors des optimisations Windows: $_" | Out-File -FilePath $logFile -Append
    }
}
Optimize-WindowsServer

# Configuration du pare-feu Windows
function Configure-Firewall {
    try {
        # Autoriser RDP
        netsh advfirewall firewall set rule group="Remote Desktop" new enable=yes
        
        # Bloquer tout le reste par défaut
        netsh advfirewall set allprofiles firewallpolicy blockinbound,allowoutbound
        
        "Pare-feu Windows configuré." | Out-File -FilePath $logFile -Append
    } catch {
        "ERREUR lors de la configuration du pare-feu: $_" | Out-File -FilePath $logFile -Append
    }
}
Configure-Firewall

# Installation et configuration de l'agent CloudWatch
function Install-CloudWatchAgent {
    try {
        # Créer le dossier pour l'agent CloudWatch
        New-Item -Path "C:\CloudWatch" -ItemType Directory -Force | Out-Null
        "Dossier C:\CloudWatch créé." | Out-File -FilePath $logFile -Append
        
        # Télécharger l'agent CloudWatch
        $cloudWatchAgentUrl = "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
        $cloudWatchAgentMsi = "C:\CloudWatch\amazon-cloudwatch-agent.msi"
        
        "Téléchargement de l'agent CloudWatch..." | Out-File -FilePath $logFile -Append
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $cloudWatchAgentUrl -OutFile $cloudWatchAgentMsi
        "Agent CloudWatch téléchargé." | Out-File -FilePath $logFile -Append
        
        # Installer l'agent CloudWatch
        "Installation de l'agent CloudWatch..." | Out-File -FilePath $logFile -Append
        Start-Process -FilePath msiexec.exe -ArgumentList "/i $cloudWatchAgentMsi /qn" -Wait
        "Agent CloudWatch installé." | Out-File -FilePath $logFile -Append
        
        # Configurer l'agent CloudWatch
        $cloudWatchConfig = @"
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "c:\\CloudWatch\\logs\\amazon-cloudwatch-agent.log"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "C:\\Windows\\Temp\\init_windows.log",
            "log_group_name": "/ec2/mt5-instance",
            "log_stream_name": "init-script",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          },
          {
            "file_path": "C:\\Windows\\Temp\\user_data_execution.log",
            "log_group_name": "/ec2/mt5-instance",
            "log_stream_name": "user-data",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          },
          {
            "file_path": "C:\\MT5\\logs\\*.log",
            "log_group_name": "/ec2/mt5-instance",
            "log_stream_name": "metatrader",
            "timestamp_format": "%Y-%m-%d %H:%M:%S"
          }
        ]
      },
      "windows_events": {
        "collect_list": [
          {
            "event_name": "System",
            "event_levels": ["ERROR", "WARNING", "CRITICAL"],
            "log_group_name": "/ec2/mt5-instance",
            "log_stream_name": "system-events"
          },
          {
            "event_name": "Application",
            "event_levels": ["ERROR", "WARNING", "CRITICAL"],
            "log_group_name": "/ec2/mt5-instance",
            "log_stream_name": "application-events"
          }
        ]
      }
    }
  }
}
"@
        $cloudWatchConfigPath = "C:\CloudWatch\config.json"
        $cloudWatchConfig | Out-File -FilePath $cloudWatchConfigPath -Encoding ascii
        "Configuration de l'agent CloudWatch créée." | Out-File -FilePath $logFile -Append
        
        # Démarrer l'agent CloudWatch
        "Démarrage de l'agent CloudWatch..." | Out-File -FilePath $logFile -Append
        & "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1" -a fetch-config -m ec2 -s -c file:$cloudWatchConfigPath
        "Agent CloudWatch démarré." | Out-File -FilePath $logFile -Append
        
        return $true
    } catch {
        "ERREUR lors de l'installation de l'agent CloudWatch: $_" | Out-File -FilePath $logFile -Append
        return $false
    }
}

# Création d'un dossier pour les applications
try {
    New-Item -Path "C:\MT5" -ItemType Directory -Force
    New-Item -Path "C:\MT5\logs" -ItemType Directory -Force
    "Dossiers C:\MT5 et C:\MT5\logs créés." | Out-File -FilePath $logFile -Append
} catch {
    "ERREUR lors de la création des dossiers C:\MT5: $_" | Out-File -FilePath $logFile -Append
}

# Installation de l'agent CloudWatch
"Installation de l'agent CloudWatch..." | Out-File -FilePath $logFile -Append
$cloudWatchInstalled = Install-CloudWatchAgent
if ($cloudWatchInstalled) {
    "Agent CloudWatch installé et configuré avec succès." | Out-File -FilePath $logFile -Append
} else {
    "Échec de l'installation de l'agent CloudWatch." | Out-File -FilePath $logFile -Append
}

# Journalisation de fin d'initialisation
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
"Initialisation terminée à $timestamp" | Out-File -FilePath $logFile -Append

# Créer un fichier de marqueur pour indiquer que le script a été exécuté
"Script exécuté avec succès" | Out-File -FilePath "C:\Windows\Temp\init_complete.marker"
