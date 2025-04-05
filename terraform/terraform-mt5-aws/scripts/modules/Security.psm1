# Module de sécurité pour les scripts d'initialisation
# Ce module fournit des fonctions pour configurer les paramètres de sécurité

# Désactiver IE Enhanced Security Configuration
function Disable-IEESC {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
        $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
        Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
        Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
        Write-Log -Message "IE Enhanced Security Configuration (ESC) désactivé." -LogFile $LogFilePath
        return $true
    } 
    catch {
        Write-Log -Message "ERREUR lors de la désactivation de IE ESC: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Configuration des paramètres de sécurité Windows
function Set-SecuritySettings {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath
    )
    
    try {
        # Activer le pare-feu Windows
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        Write-Log -Message "Pare-feu Windows activé sur tous les profils." -LogFile $LogFilePath
        
        # Configurer l'exécution des scripts PowerShell
        Set-ExecutionPolicy Unrestricted -Force
        Write-Log -Message "ExecutionPolicy configurée en Unrestricted" -LogFile $LogFilePath
        
        # Désactiver l'accès à distance sauf pour les administrateurs
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
        Set-ItemProperty -Path $regPath -Name "fDenyTSConnections" -Value 0
        Write-Log -Message "Accès Bureau à distance activé." -LogFile $LogFilePath
        
        # Configurer NTP pour la synchronisation de l'heure
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters" -Name "NtpServer" -Value "pool.ntp.org,0x1"
        Restart-Service w32time
        Write-Log -Message "Service de temps configuré avec pool.ntp.org." -LogFile $LogFilePath
        
        return $true
    }
    catch {
        Write-Log -Message "ERREUR lors de la configuration des paramètres de sécurité: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Exporter les fonctions du module
Export-ModuleMember -Function Disable-IEESC, Set-SecuritySettings
