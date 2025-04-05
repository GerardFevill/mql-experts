# Variables globales
$global:logFile = "C:\Windows\Temp\mt5_installation.log"
$global:mt5Path = "C:\Program Files\MetaTrader 5"
$global:mt5Url = "https://download.mql5.com/cdn/web/ic.markets.securities.ltd/mt5/icmarketssc5setup.exe"
$global:mt5Installer = "C:\MT5\icmarketssc5setup.exe"

# Fonction pour la journalisation
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [switch]$IsError,
        
        [Parameter(Mandatory = $false)]
        [switch]$IsWarning
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logLevel = if ($IsError) { "[ERREUR]" } elseif ($IsWarning) { "[AVERTISSEMENT]" } else { "[INFO]" }
    "[$timestamp] $logLevel $Message" | Out-File -FilePath $global:logFile -Append -Encoding UTF8
    
    if ($IsError) {
        Write-Host "[$timestamp] $logLevel $Message" -ForegroundColor Red
    } elseif ($IsWarning) {
        Write-Host "[$timestamp] $logLevel $Message" -ForegroundColor Yellow
    } else {
        Write-Host "[$timestamp] $logLevel $Message" -ForegroundColor Green
    }
}

# Fonction pour activer RDP
function Enable-RDP {
    try {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Type DWord
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        Write-Log -Message "RDP activé avec succès"
        return $true
    } catch {
        Write-Log -Message "Erreur lors de l'activation de RDP: $_" -IsError
        return $false
    }
}

# Fonction pour créer les dossiers nécessaires
function Initialize-Folders {
    try {
        New-Item -Path "C:\MT5" -ItemType Directory -Force | Out-Null
        New-Item -Path "C:\MT5\logs" -ItemType Directory -Force | Out-Null
        Write-Log -Message "Dossiers créés avec succès"
        return $true
    } catch {
        Write-Log -Message "Erreur lors de la création des dossiers: $_" -IsError
        return $false
    }
}

function Install-MT5 {
    try {
        # Configurer TLS 1.2 pour sécuriser les connexions
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        # Vérifier si MT5 est déjà installé
        if (Test-Path $global:mt5Path) {
            Write-Log -Message "MetaTrader 5 est déjà installé dans $global:mt5Path. Installation annulée."
            return $true
        }

        # Vérifier si le fichier d'installation existe déjà
        if (-Not (Test-Path $global:mt5Installer)) {
            Write-Log -Message "Téléchargement de MetaTrader 5 depuis $global:mt5Url..."
            Invoke-WebRequest -Uri $global:mt5Url -OutFile $global:mt5Installer
        } else {
            Write-Log -Message "Le fichier d'installation existe déjà à $global:mt5Installer. Téléchargement ignoré."
        }

        # Installer MT5 silencieusement
        Write-Log -Message "Installation de MetaTrader 5..."
        Start-Process -FilePath $global:mt5Installer -ArgumentList "/auto" -Wait

        # Vérifier l'installation
        if (Test-Path $global:mt5Path) {
            Write-Log -Message "MetaTrader 5 installé avec succès dans $global:mt5Path."
            return $true
        } else {
            Write-Log -Message "Le dossier d'installation de MetaTrader 5 est introuvable après l'installation." -IsWarning
            return $false
        }
    } catch {
        Write-Log -Message "Erreur lors de l'installation de MetaTrader 5: $_" -IsError
        return $false
    }
}


# Fonction pour installer AWS CLI
function Install-AWSCLI {
    try {
        if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
            Write-Log -Message "Installation d'AWS CLI..."
            $awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
            $awsCliInstaller = "C:\MT5\AWSCLIV2.msi"
            Invoke-WebRequest -Uri $awsCliUrl -OutFile $awsCliInstaller
            Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $awsCliInstaller /quiet /norestart" -Wait
            
            # Ajouter manuellement le chemin d'installation de AWS CLI à l'environnement
            $awsCliPath = "$env:ProgramFiles\Amazon\AWSCLIV2"
            $env:Path += ";$awsCliPath;$awsCliPath\bin"
            
            # Vérifier que AWS CLI est maintenant accessible
            if (Get-Command aws -ErrorAction SilentlyContinue) {
                Write-Log -Message "AWS CLI installé et accessible"
            } else {
                Write-Log -Message "AWS CLI installé mais non accessible dans le PATH" -IsWarning
            }
            
            Write-Log -Message "AWS CLI installé"
            return $true
        } else {
            Write-Log -Message "AWS CLI déjà installé"
            return $true
        }
    } catch {
        Write-Log -Message "Erreur lors de l'installation d'AWS CLI: $_" -IsError
        return $false
    }
}

# Fonction pour récupérer le mot de passe MT5 depuis AWS Secrets Manager
function Get-MT5Password {
    try {
        $region = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/placement/region"
        
        # Installer AWS CLI si nécessaire
        if (-not (Install-AWSCLI)) {
            Write-Log -Message "Impossible d'installer AWS CLI pour récupérer le secret" -IsError
            return $null
        }
        
        # Rechercher les secrets avec le tag Name=mt5-password
        Write-Log -Message "Recherche du secret MT5 par tag dans AWS Secrets Manager..."
        
        try {
            # Liste des secrets avec le tag Name=mt5-password
            $secretsList = aws secretsmanager list-secrets --filter Key="tag-key",Values="Name" --region $region | ConvertFrom-Json
            
            # Filtrer les secrets qui ont le tag Name=mt5-password
            $mt5Secrets = $secretsList.SecretList | Where-Object { 
                $_.Tags | Where-Object { $_.Key -eq "Name" -and $_.Value -eq "mt5-password" } 
            }
            
            if ($null -eq $mt5Secrets -or $mt5Secrets.Count -eq 0) {
                Write-Log -Message "Aucun secret avec le tag Name=mt5-password n'a été trouvé" -IsError
                return $null
            }
            
            # Prendre le premier secret trouvé (le plus récent si plusieurs existent)
            $secretName = $mt5Secrets[0].Name
            Write-Log -Message "Secret trouvé avec le tag Name=mt5-password: $secretName"
            
            # Récupérer la valeur du secret
            $secretValue = aws secretsmanager get-secret-value --secret-id $secretName --region $region | ConvertFrom-Json
            $password = $secretValue.SecretString
            
            Write-Log -Message "Mot de passe MT5 récupéré depuis AWS Secrets Manager"
            return $password
        } catch {
            Write-Log -Message "Erreur lors de la recherche du secret par tag: $_" -IsError
            
            # Plan B: Essayer de trouver un secret dont le nom commence par mt5-password
            Write-Log -Message "Tentative alternative: recherche par préfixe 'mt5-password'..."
            try {
                $secretsList = aws secretsmanager list-secrets --filter Key="name",Values="mt5-password" --region $region | ConvertFrom-Json
                
                if ($null -eq $secretsList.SecretList -or $secretsList.SecretList.Count -eq 0) {
                    Write-Log -Message "Aucun secret avec le préfixe 'mt5-password' n'a été trouvé" -IsError
                    return $null
                }
                
                $secretName = $secretsList.SecretList[0].Name
                Write-Log -Message "Secret trouvé par préfixe: $secretName"
                
                $secretValue = aws secretsmanager get-secret-value --secret-id $secretName --region $region | ConvertFrom-Json
                $password = $secretValue.SecretString
                
                Write-Log -Message "Mot de passe MT5 récupéré depuis AWS Secrets Manager (méthode alternative)"
                return $password
            } catch {
                Write-Log -Message "Toutes les tentatives de récupération du secret ont échoué" -IsError
                return $null
            }
        }
    } catch {
        Write-Log -Message "Erreur lors de la récupération du mot de passe depuis AWS Secrets Manager: $_" -IsError
        return $null
    }
}

# Fonction pour récupérer les tags de l'instance
function Get-InstanceTags {
    try {
        # Récupérer l'ID de l'instance et la région depuis les métadonnées
        Write-Log -Message "Récupération des métadonnées de l'instance..."
        $instanceId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id"
        $region = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/placement/region"
        Write-Log -Message "Instance ID: $instanceId, Région: $region"
        
        # Installer AWS CLI si nécessaire
        if (-not (Install-AWSCLI)) {
            Write-Log -Message "Impossible d'installer AWS CLI pour récupérer les tags" -IsError
            return $null
        }
        
        # Récupérer les tags avec gestion d'erreur
        Write-Log -Message "Récupération des tags de l'instance..."
        try {
            $tagsOutput = aws ec2 describe-tags --filters "Name=resource-id,Values=$instanceId" --region $region
            $tags = $tagsOutput | ConvertFrom-Json
            
            # Vérifier que des tags ont été trouvés
            if ($null -eq $tags.Tags -or $tags.Tags.Count -eq 0) {
                Write-Log -Message "Aucun tag trouvé pour l'instance $instanceId" -IsWarning
            }
            
            # Récupérer les tags spécifiques avec vérification
            $mt5Login = ($tags.Tags | Where-Object { $_.Key -eq "MT5_LOGIN" }).Value
            $mt5Server = ($tags.Tags | Where-Object { $_.Key -eq "MT5_SERVER" }).Value
            
            # Vérifier que les tags requis sont présents
            if ([string]::IsNullOrEmpty($mt5Login)) {
                Write-Log -Message "Le tag MT5_LOGIN est manquant ou vide" -IsWarning
                $mt5Login = "" # Valeur par défaut vide
            }
            
            if ([string]::IsNullOrEmpty($mt5Server)) {
                Write-Log -Message "Le tag MT5_SERVER est manquant ou vide" -IsWarning
                $mt5Server = "" # Valeur par défaut vide
            }
            
            Write-Log -Message "Tags récupérés - MT5_LOGIN: $mt5Login, MT5_SERVER: $mt5Server"
        } catch {
            Write-Log -Message "Erreur lors de la récupération des tags: $_" -IsError
            return $null
        }
        
        # Récupérer le mot de passe depuis AWS Secrets Manager
        $mt5Password = Get-MT5Password
        if ($null -eq $mt5Password) {
            Write-Log -Message "Impossible de récupérer le mot de passe MT5 depuis AWS Secrets Manager" -IsError
            return $null
        }
        
        Write-Log -Message "Tags récupérés - MT5_LOGIN: $mt5Login, MT5_SERVER: $mt5Server, MT5_PASSWORD: ***"
        
        return @{
            Login = $mt5Login
            Server = $mt5Server
            Password = $mt5Password
        }
    } catch {
        Write-Log -Message "Erreur lors de la récupération des tags: $_" -IsError
        return $null
    }
}

# Fonction pour configurer MT5
function Configure-MT5 {
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Tags
    )
    
    try {
        # Vérifier que les valeurs nécessaires sont présentes
        Write-Log -Message "Vérification des paramètres de configuration MT5..."
        
        # Vérifier le login
        if ([string]::IsNullOrEmpty($Tags.Login)) {
            Write-Log -Message "Le login MT5 est manquant ou vide" -IsWarning
        }
        
        # Vérifier le mot de passe
        if ([string]::IsNullOrEmpty($Tags.Password)) {
            Write-Log -Message "Le mot de passe MT5 est manquant ou vide" -IsError
            return $false
        }
        
        # Vérifier le serveur
        if ([string]::IsNullOrEmpty($Tags.Server)) {
            Write-Log -Message "Le serveur MT5 est manquant ou vide" -IsWarning
        }
        
        # Vérifier que le chemin d'installation de MT5 existe
        if (-not (Test-Path $global:mt5Path)) {
            Write-Log -Message "Le chemin d'installation de MT5 n'existe pas: $global:mt5Path" -IsError
            return $false
        }
        
        # Créer le dossier config s'il n'existe pas
        $configDir = "$global:mt5Path\config"
        if (-not (Test-Path $configDir)) {
            Write-Log -Message "Création du dossier de configuration: $configDir"
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        # Définir le chemin du fichier de configuration
        $mt5ConfigPath = "$configDir\mt5.ini"
        Write-Log -Message "Création du fichier de configuration MT5: $mt5ConfigPath"
        
        # Contenu du fichier de configuration avec commentaires
        $mt5Config = @"
; Configuration MetaTrader 5 générée automatiquement le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

[Common]
Login=$($Tags.Login)
Password=$($Tags.Password)
Server=$($Tags.Server)
KeepPrivate=1 ; Empêche l'affichage des informations de connexion
NewsEnable=0   ; Désactive les nouvelles pour réduire les distractions

[Experts]
AllowLiveTrading=1 ; Autorise le trading réel
AllowDllImport=1   ; Autorise l'importation de DLL (nécessaire pour certains EAs)
Enabled=1          ; Active les Expert Advisors
Account=0          ; Utilise le compte actuel
Profile=0          ; Utilise le profil par défaut

[StartUp]
Expert=ForexGoldInvestor_v1.98_MT5.ex5 ; Expert Advisor à charger automatiquement
Symbol=XAUUSD                          ; Symbole GOLD/USD
Period=M15                             ; Timeframe 15 minutes
Template=Default                       ; Template par défaut
ExpertParameters=ForexGoldInvestor_v1.98_MT5.set ; Fichier de paramètres
ShutdownTerminal=0                     ; Ne pas fermer MT5 après une erreur
"@
        
        # Écrire le fichier de configuration avec encodage ASCII pour éviter les problèmes de caractères
        $mt5Config | Out-File -FilePath $mt5ConfigPath -Encoding ASCII -Force
        
        # Vérifier que le fichier a bien été créé
        if (Test-Path $mt5ConfigPath) {
            Write-Log -Message "Fichier de configuration MT5 créé avec succès: $mt5ConfigPath"
            return $true
        } else {
            Write-Log -Message "Impossible de vérifier la création du fichier de configuration: $mt5ConfigPath" -IsError
            return $false
        }
    } catch {
        Write-Log -Message "Erreur lors de la configuration de MT5: $_" -IsError
        return $false
    }
}

# Fonction pour démarrer MT5 en mode graphique
function Start-MT5GraphicalMode {
    try {
        # Démarrer MT5 directement avec l'option /portable pour forcer l'affichage graphique
        Write-Log -Message "Démarrage de MetaTrader 5 en mode graphique..."
        
        # Construire le chemin du fichier de configuration
        $mt5ConfigPath = "$global:mt5Path\config\mt5.ini"
        
        # Vérifier que le fichier de configuration existe
        if (Test-Path $mt5ConfigPath) {
            # Utiliser des arguments séparés pour éviter les problèmes de guillemets
            Start-Process -FilePath "$global:mt5Path\terminal64.exe" -ArgumentList "/config:`"$mt5ConfigPath`""
            Write-Log -Message "MetaTrader 5 démarré avec le fichier de configuration et en mode graphique"
        } else {
            # Si le fichier de configuration n'existe pas, démarrer MT5 uniquement avec l'option portable
            Start-Process -FilePath "$global:mt5Path\terminal64.exe" -ArgumentList "/portable" -WindowStyle Normal
            Write-Log -Message "MetaTrader 5 démarré en mode graphique (sans fichier de configuration)"
        }
        
        return $true
    } catch {
        Write-Log -Message "Erreur lors du démarrage de MT5: $_" -IsError
        return $false
    }
}

# Fonction pour télécharger les fichiers EA depuis S3
function Download-EAFiles {
    try {
        # Vérifier que AWS CLI est installé
        if (-not (Install-AWSCLI)) {
            Write-Log -Message "Impossible d'installer AWS CLI, téléchargement des fichiers EA impossible" -IsError
            return $false
        }
        
        # Créer le dossier MQL5 s'il n'existe pas
        $mql5Path = "$global:mt5Path\MQL5"
        if (-not (Test-Path $mql5Path)) {
            New-Item -Path $mql5Path -ItemType Directory -Force | Out-Null
        }
        
        # Créer le dossier Experts s'il n'existe pas
        $expertsPath = "$mql5Path\Experts"
        if (-not (Test-Path $expertsPath)) {
            New-Item -Path $expertsPath -ItemType Directory -Force | Out-Null
        }
        
        # Créer le dossier Presets s'il n'existe pas
        $presetsPath = "$mql5Path\Presets"
        if (-not (Test-Path $presetsPath)) {
            New-Item -Path $presetsPath -ItemType Directory -Force | Out-Null
        }
        
        # Télécharger le fichier EA (.ex5)
        $eaS3Path = "s3://ea-trading-bucket/ea/ForexGoldInvestor_v1.98_MT5.ex5"
        $eaLocalPath = "$expertsPath\ForexGoldInvestor_v1.98_MT5.ex5"
        Write-Log -Message "Téléchargement du fichier EA depuis $eaS3Path..."
        aws s3 cp $eaS3Path $eaLocalPath
        
        # Télécharger le fichier de configuration (.set)
        $setS3Path = "s3://ea-trading-bucket/ea/ForexGoldInvestor_v1.98_MT5.set"
        $setLocalPath = "$presetsPath\ForexGoldInvestor_v1.98_MT5.set"
        Write-Log -Message "Téléchargement du fichier de configuration depuis $setS3Path..."
        aws s3 cp $setS3Path $setLocalPath
        
        # Vérifier que les fichiers ont bien été téléchargés
        if (Test-Path $eaLocalPath) {
            Write-Log -Message "Fichier EA téléchargé avec succès dans $eaLocalPath"
        } else {
            Write-Log -Message "Erreur lors du téléchargement du fichier EA" -IsError
        }
        
        if (Test-Path $setLocalPath) {
            Write-Log -Message "Fichier de configuration téléchargé avec succès dans $setLocalPath"
        } else {
            Write-Log -Message "Erreur lors du téléchargement du fichier de configuration" -IsError
        }
        
        return (Test-Path $eaLocalPath) -and (Test-Path $setLocalPath)
    } catch {
        Write-Log -Message "Erreur lors du téléchargement des fichiers EA: $_" -IsError
        return $false
    }
}


# Fonction principale
function Main {
    Write-Log -Message "Démarrage de l'installation de MT5"
    
    # Étape 1: Activer RDP
    if (-not (Enable-RDP)) {
        Write-Log -Message "Impossible d'activer RDP, mais on continue..." -IsWarning
    }
    
    # Étape 2: Initialiser les dossiers
    if (-not (Initialize-Folders)) {
        Write-Log -Message "Impossible de créer les dossiers nécessaires, mais on continue..." -IsWarning
    }
    
    # Étape 3: Installer MT5
    if (-not (Install-MT5)) {
        Write-Log -Message "L'installation de MT5 a échoué, arrêt du processus" -IsError
        return
    }
    
    # Étape 3b: Télécharger les fichiers EA depuis S3
    if (-not (Download-EAFiles)) {
        Write-Log -Message "Le téléchargement des fichiers EA a échoué, mais on continue..." -IsWarning
    } else {
        Write-Log -Message "Fichiers EA téléchargés avec succès"
    }
    
    # Étape 4: Récupérer les tags
    $tags = Get-InstanceTags
    if ($null -eq $tags) {
        Write-Log -Message "Impossible de récupérer les tags, arrêt du processus" -IsError
        return
    }
    
    # Étape 5: Configurer MT5
    if (-not (Configure-MT5 -Tags $tags)) {
        Write-Log -Message "La configuration de MT5 a échoué, mais on continue..." -IsWarning
    }
    
    # Étape 6: Démarrer MT5 en mode graphique
    if (-not (Start-MT5GraphicalMode)) {
        Write-Log -Message "Le démarrage de MT5 en mode graphique a échoué, mais on continue..." -IsWarning
    }
    
    Write-Log -Message "Installation terminée"
}

# Exécuter la fonction principale
Main
