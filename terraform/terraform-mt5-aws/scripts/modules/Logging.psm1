# Module de journalisation pour les scripts d'initialisation
# Ce module fournit des fonctions pour la journalisation standardisée

# Fonction de journalisation centralisée
function Write-Log {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        
        [Parameter(Mandatory = $false)]
        [switch]$IsError,
        
        [Parameter(Mandatory = $false)]
        [switch]$IsWarning
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] "
    
    if ($IsError) {
        $logEntry += "[ERREUR] "
    }
    elseif ($IsWarning) {
        $logEntry += "[AVERTISSEMENT] "
    }
    else {
        $logEntry += "[INFO] "
    }
    
    $logEntry += $Message
    $logEntry | Out-File -FilePath $LogFile -Append
    
    # Afficher également dans la console pour le débogage
    if ($IsError) {
        Write-Host $logEntry -ForegroundColor Red
    }
    elseif ($IsWarning) {
        Write-Host $logEntry -ForegroundColor Yellow
    }
    else {
        Write-Host $logEntry -ForegroundColor Green
    }
}

# Fonction pour initialiser le fichier de log
function Initialize-LogFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    # Créer le dossier parent si nécessaire
    $logDir = Split-Path -Path $LogFilePath -Parent
    if (-not (Test-Path -Path $logDir)) {
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    }
    
    # Créer ou vider le fichier de log
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] [INFO] Démarrage de la journalisation" | Out-File -FilePath $LogFilePath -Force
    
    return $LogFilePath
}

# Exporter les fonctions du module
Export-ModuleMember -Function Write-Log, Initialize-LogFile
