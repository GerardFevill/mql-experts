# Module d'optimisation pour les scripts d'initialisation
# Ce module fournit des fonctions pour optimiser les performances de Windows Server

# Importer le module de journalisation
# Import-Module "$PSScriptRoot\Logging.psm1"

# Optimisations pour réduire l'utilisation des ressources
function Optimize-WindowsServer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
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
                Write-Log -Message "Service $service désactivé." -LogFile $LogFilePath
            }
        }

        # Désactiver les tâches planifiées inutiles
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\Application Experience\ProgramDataUpdater" -ErrorAction SilentlyContinue
        Disable-ScheduledTask -TaskName "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator" -ErrorAction SilentlyContinue
        Write-Log -Message "Tâches planifiées inutiles désactivées." -LogFile $LogFilePath
        
        # Désactiver les effets visuels pour améliorer les performances
        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
        if (!(Test-Path $path)) {
            New-Item -Path $path -Force | Out-Null
        }
        Set-ItemProperty -Path $path -Name "VisualFXSetting" -Value 2
        
        # Optimiser les performances du processeur
        $powerPlan = powercfg -l | Where-Object { $_ -match "Hautes performances" }
        if ($powerPlan) {
            $guid = ($powerPlan -split " ")[3]
            powercfg -setactive $guid
            Write-Log -Message "Plan d'alimentation 'Hautes performances' activé." -LogFile $LogFilePath
        }
        
        # Désactiver l'indexation sur le disque système
        $systemDrive = $env:SystemDrive
        $drive = Get-WmiObject -Class Win32_Volume -Filter "DriveLetter = '$systemDrive'"
        if ($drive.IndexingEnabled) {
            $drive.IndexingEnabled = $false
            $drive.Put() | Out-Null
            Write-Log -Message "Indexation désactivée sur le disque système." -LogFile $LogFilePath
        }
        
        Write-Log -Message "Optimisations Windows Server terminées." -LogFile $LogFilePath
        return $true
    } 
    catch {
        Write-Log -Message "ERREUR lors des optimisations Windows: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Fonction pour nettoyer les fichiers temporaires
function Clear-TempFiles {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        # Nettoyer les dossiers temporaires
        $tempFolders = @(
            "$env:TEMP",
            "$env:SystemRoot\Temp",
            "$env:SystemRoot\Prefetch"
        )
        
        foreach ($folder in $tempFolders) {
            if (Test-Path -Path $folder) {
                Get-ChildItem -Path $folder -Force -ErrorAction SilentlyContinue | 
                    Where-Object { ($_.CreationTime -lt (Get-Date).AddDays(-2)) } | 
                    Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        
        Write-Log -Message "Fichiers temporaires nettoyés." -LogFile $LogFilePath
        return $true
    }
    catch {
        Write-Log -Message "ERREUR lors du nettoyage des fichiers temporaires: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Exporter les fonctions du module
Export-ModuleMember -Function Optimize-WindowsServer, Clear-TempFiles
