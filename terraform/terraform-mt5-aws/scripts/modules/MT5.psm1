# Module MT5 pour l'installation et la configuration de MetaTrader 5
# Ce module fournit des fonctions pour télécharger et installer MetaTrader 5

# Télécharger et installer MetaTrader 5
function Install-MT5 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$S3Bucket = "ea-trading-bucket",
        
        [Parameter(Mandatory = $false)]
        [string]$S3Key = "ea/icmarketssc5setup.exe",
        
        [Parameter(Mandatory = $false)]
        [string]$InstallDir = "C:\MT5",
        
        [Parameter(Mandatory = $false)]
        [string]$FallbackUrl = "https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"
    )
    
    try {
        # Créer le dossier d'installation s'il n'existe pas
        if (-not (Test-Path -Path $InstallDir)) {
            New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
            Write-Log -Message "Dossier d'installation $InstallDir créé." -LogFile $LogFilePath
        }
        
        # Définir le chemin du fichier d'installation
        $installerName = Split-Path -Path $S3Key -Leaf
        $installerPath = Join-Path -Path $InstallDir -ChildPath $installerName
        
        # Télécharger depuis S3
        Write-Log -Message "Tentative de téléchargement de MT5 depuis S3 ($S3Bucket/$S3Key)..." -LogFile $LogFilePath
        $s3Downloaded = Get-MT5FromS3 -S3Bucket $S3Bucket -S3Key $S3Key -OutputPath $installerPath -LogFilePath $LogFilePath
        
        # Si le téléchargement depuis S3 a échoué, utiliser l'URL de fallback
        if (-not $s3Downloaded) {
            Write-Log -Message "Téléchargement depuis S3 échoué. Tentative de téléchargement depuis l'URL de fallback..." -LogFile $LogFilePath -IsWarning
            $fallbackInstallerPath = Join-Path -Path $InstallDir -ChildPath "mt5setup.exe"
            $fallbackDownloaded = Get-MT5FromUrl -Url $FallbackUrl -OutputPath $fallbackInstallerPath -LogFilePath $LogFilePath
            
            if ($fallbackDownloaded) {
                $installerPath = $fallbackInstallerPath
                Write-Log -Message "Téléchargement depuis l'URL de fallback réussi." -LogFile $LogFilePath
            } else {
                throw "Impossible de télécharger MT5 depuis S3 ou l'URL de fallback."
            }
        }
        
        # Vérifier que le fichier existe
        if (-not (Test-Path -Path $installerPath)) {
            throw "Le fichier d'installation n'existe pas au chemin spécifié: $installerPath"
        }
        
        # Installer MT5 silencieusement
        Write-Log -Message "Installation de MetaTrader 5..." -LogFile $LogFilePath
        $installProcess = Start-Process -FilePath $installerPath -ArgumentList "/auto" -Wait -PassThru
        
        if ($installProcess.ExitCode -ne 0) {
            throw "L'installation de MetaTrader 5 a échoué avec le code d'erreur $($installProcess.ExitCode)."
        }
        
        Write-Log -Message "MetaTrader 5 installé avec succès." -LogFile $LogFilePath
        
        # Détecter le chemin d'installation réel de MT5
        $mt5Path = Find-MT5InstallPath -LogFilePath $LogFilePath
        
        if ($mt5Path) {
            Write-Log -Message "MetaTrader 5 détecté à l'emplacement: $mt5Path" -LogFile $LogFilePath
            return $mt5Path
        } else {
            Write-Log -Message "Impossible de détecter l'emplacement d'installation de MetaTrader 5. Utilisation du chemin par défaut." -LogFile $LogFilePath -IsWarning
            return "C:\Program Files\MetaTrader 5"
        }
    } 
    catch {
        Write-Log -Message "ERREUR lors de l'installation de MetaTrader 5: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Télécharger MetaTrader 5 depuis S3
function Get-MT5FromS3 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$S3Bucket,
        
        [Parameter(Mandatory = $true)]
        [string]$S3Key,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        Write-Log -Message "Téléchargement du fichier depuis S3: s3://$S3Bucket/$S3Key" -LogFile $LogFilePath
        
        # Vérifier si AWS CLI est installé
        $awsCommand = Get-Command aws -ErrorAction SilentlyContinue
        if (-not $awsCommand) {
            Write-Log -Message "AWS CLI n'est pas installé. Tentative de téléchargement direct depuis S3 impossible." -LogFile $LogFilePath -IsWarning
            return $false
        }
        
        # Télécharger le fichier depuis S3
        $tempOutputPath = "$OutputPath.tmp"
        aws s3 cp "s3://$S3Bucket/$S3Key" $tempOutputPath
        
        if (Test-Path -Path $tempOutputPath) {
            Move-Item -Path $tempOutputPath -Destination $OutputPath -Force
            Write-Log -Message "Fichier téléchargé avec succès depuis S3: $OutputPath" -LogFile $LogFilePath
            return $true
        } else {
            Write-Log -Message "Échec du téléchargement depuis S3." -LogFile $LogFilePath -IsWarning
            return $false
        }
    } 
    catch {
        Write-Log -Message "ERREUR lors du téléchargement depuis S3: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Télécharger MetaTrader 5 depuis une URL
function Get-MT5FromUrl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        Write-Log -Message "Téléchargement du fichier depuis l'URL: $Url" -LogFile $LogFilePath
        
        # Configurer TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        
        # Télécharger le fichier
        $tempOutputPath = "$OutputPath.tmp"
        Invoke-WebRequest -Uri $Url -OutFile $tempOutputPath
        
        if (Test-Path -Path $tempOutputPath) {
            Move-Item -Path $tempOutputPath -Destination $OutputPath -Force
            Write-Log -Message "Fichier téléchargé avec succès depuis l'URL: $OutputPath" -LogFile $LogFilePath
            return $true
        } else {
            Write-Log -Message "Échec du téléchargement depuis l'URL." -LogFile $LogFilePath -IsWarning
            return $false
        }
    } 
    catch {
        Write-Log -Message "ERREUR lors du téléchargement depuis l'URL: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Trouver le chemin d'installation de MetaTrader 5
function Find-MT5InstallPath {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        # Chemins possibles d'installation
        $possiblePaths = @(
            "C:\Program Files\MetaTrader 5",
            "C:\Program Files (x86)\MetaTrader 5",
            "C:\Program Files\MetaTrader 5 IC Markets",
            "C:\Program Files (x86)\MetaTrader 5 IC Markets"
        )
        
        foreach ($path in $possiblePaths) {
            if (Test-Path -Path $path) {
                Write-Log -Message "Chemin d'installation de MetaTrader 5 trouvé: $path" -LogFile $LogFilePath
                return $path
            }
        }
        
        # Rechercher dans le registre
        $regPaths = @(
            "HKLM:\SOFTWARE\MetaQuotes\MetaTrader 5",
            "HKLM:\SOFTWARE\WOW6432Node\MetaQuotes\MetaTrader 5"
        )
        
        foreach ($regPath in $regPaths) {
            if (Test-Path -Path $regPath) {
                $installPath = (Get-ItemProperty -Path $regPath -Name "Install_Dir" -ErrorAction SilentlyContinue).Install_Dir
                if ($installPath -and (Test-Path -Path $installPath)) {
                    Write-Log -Message "Chemin d'installation de MetaTrader 5 trouvé dans le registre: $installPath" -LogFile $LogFilePath
                    return $installPath
                }
            }
        }
        
        Write-Log -Message "Impossible de trouver le chemin d'installation de MetaTrader 5." -LogFile $LogFilePath -IsWarning
        return $null
    } 
    catch {
        Write-Log -Message "ERREUR lors de la recherche du chemin d'installation de MetaTrader 5: $_" -LogFile $LogFilePath -IsError
        return $null
    }
}

# Configurer MetaTrader 5 avec les identifiants
function Set-MT5Credentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MT5Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Login,
        
        [Parameter(Mandatory = $true)]
        [string]$Password,
        
        [Parameter(Mandatory = $true)]
        [string]$Server,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        # Créer le fichier de configuration
        $configDir = Join-Path -Path $MT5Path -ChildPath "config"
        if (-not (Test-Path -Path $configDir)) {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        }
        
        $configPath = Join-Path -Path $configDir -ChildPath "mt5.ini"
        
        # Créer le contenu du fichier de configuration
        $configContent = @"
[Login]
Login=$Login
Password=$Password
Server=$Server
AutoConnect=1
EnableNews=0

[Common]
AllowLiveTrading=1
AllowDllImport=1
DisableOpenCL=0
"@
        
        # Écrire le fichier de configuration
        $configContent | Out-File -FilePath $configPath -Encoding ascii
        
        Write-Log -Message "Fichier de configuration MT5 créé: $configPath" -LogFile $LogFilePath
        return $true
    } 
    catch {
        Write-Log -Message "ERREUR lors de la configuration des identifiants MT5: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Créer une tâche planifiée pour démarrer MT5 au démarrage
function Register-MT5StartupTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MT5Path,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        $terminalExe = Join-Path -Path $MT5Path -ChildPath "terminal64.exe"
        if (-not (Test-Path -Path $terminalExe)) {
            $terminalExe = Join-Path -Path $MT5Path -ChildPath "terminal.exe"
        }
        
        if (-not (Test-Path -Path $terminalExe)) {
            throw "Impossible de trouver l'exécutable de MetaTrader 5."
        }
        
        # Créer une action pour la tâche planifiée avec démarrage minimisé
        $action = New-ScheduledTaskAction -Execute $terminalExe -Argument "/portable"
        
        # Créer un déclencheur pour la tâche planifiée (au démarrage avec délai de 2 minutes)
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $trigger.Delay = 'PT2M'
        
        # Créer les paramètres de la tâche planifiée
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        # Créer et enregistrer la tâche planifiée
        Register-ScheduledTask -TaskName "MetaTrader5Startup" -Action $action -Trigger $trigger -Settings $settings -User "SYSTEM" -Force
        
        Write-Log -Message "Tâche planifiée pour démarrer MetaTrader 5 au démarrage créée." -LogFile $LogFilePath
        return $true
    } 
    catch {
        Write-Log -Message "ERREUR lors de la création de la tâche planifiée: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Démarrer MetaTrader 5
function Start-MT5 {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MT5Path,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        $terminalExe = Join-Path -Path $MT5Path -ChildPath "terminal64.exe"
        if (-not (Test-Path -Path $terminalExe)) {
            $terminalExe = Join-Path -Path $MT5Path -ChildPath "terminal.exe"
        }
        
        if (-not (Test-Path -Path $terminalExe)) {
            throw "Impossible de trouver l'exécutable de MetaTrader 5."
        }
        
        # Démarrer MetaTrader 5 en mode minimisé
        Start-Process -FilePath $terminalExe -WindowStyle Minimized
        
        Write-Log -Message "MetaTrader 5 démarré en mode minimisé." -LogFile $LogFilePath
        return $true
    } 
    catch {
        Write-Log -Message "ERREUR lors du démarrage de MetaTrader 5: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Exporter les fonctions du module
Export-ModuleMember -Function Install-MT5, Set-MT5Credentials, Register-MT5StartupTask, Start-MT5
