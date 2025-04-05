# Module de pare-feu pour les scripts d'initialisation
# Ce module fournit des fonctions pour configurer le pare-feu Windows

# Configuration du pare-feu Windows
function Configure-Firewall {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath,
        
        [Parameter(Mandatory = $false)]
        [string[]]$AllowedIPs = @("0.0.0.0/0")
    )
    
    try {
        # Activer le pare-feu sur tous les profils
        Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
        Write-Log -Message "Pare-feu Windows activé sur tous les profils." -LogFile $LogFilePath
        
        # Autoriser RDP (s'assurer que toutes les règles sont activées)
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
        
        # S'assurer que le service RDP est activé
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Type DWord
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 -Type DWord
        
        # Activer le service RDP
        Set-Service -Name TermService -StartupType Automatic
        Start-Service -Name TermService
        
        Write-Log -Message "Service RDP et règles de pare-feu pour Bureau à distance activés." -LogFile $LogFilePath
        
        # Configurer les règles de pare-feu pour RDP avec les IPs autorisées
        foreach ($ip in $AllowedIPs) {
            $ruleName = "RDP-Custom-$($ip.Replace('/', '-'))"
            
            # Vérifier si la règle existe déjà
            $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
            
            if ($existingRule) {
                # Mettre à jour la règle existante
                Set-NetFirewallRule -DisplayName $ruleName -Enabled True
                Write-Log -Message "Règle de pare-feu '$ruleName' mise à jour." -LogFile $LogFilePath
            } 
            else {
                # Créer une nouvelle règle
                New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -RemoteAddress $ip
                Write-Log -Message "Règle de pare-feu '$ruleName' créée pour autoriser RDP depuis $ip." -LogFile $LogFilePath
            }
        }
        
        # Autoriser ICMP (ping)
        $icmpRuleName = "ICMP-Allow-Ping"
        $icmpRule = Get-NetFirewallRule -DisplayName $icmpRuleName -ErrorAction SilentlyContinue
        
        if ($icmpRule) {
            Set-NetFirewallRule -DisplayName $icmpRuleName -Enabled True
        } 
        else {
            New-NetFirewallRule -DisplayName $icmpRuleName -Direction Inbound -Protocol ICMPv4 -IcmpType 8 -Action Allow
        }
        Write-Log -Message "Règle de pare-feu pour autoriser le ping configurée." -LogFile $LogFilePath
        
        # Autoriser les connexions sortantes par défaut
        Set-NetFirewallProfile -DefaultOutboundAction Allow -Profile Domain,Public,Private
        Write-Log -Message "Connexions sortantes autorisées par défaut." -LogFile $LogFilePath
        
        # Bloquer les connexions entrantes par défaut
        Set-NetFirewallProfile -DefaultInboundAction Block -Profile Domain,Public,Private
        Write-Log -Message "Connexions entrantes bloquées par défaut." -LogFile $LogFilePath
        
        return $true
    } 
    catch {
        Write-Log -Message "ERREUR lors de la configuration du pare-feu: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Fonction pour ouvrir un port spécifique
function Open-FirewallPort {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        
        [Parameter(Mandatory = $true)]
        [string]$LogFilePath,
        
        [Parameter(Mandatory = $false)]
        [string]$Protocol = "TCP",
        
        [Parameter(Mandatory = $false)]
        [string[]]$RemoteAddresses = @("0.0.0.0/0")
    )
    
    try {
        $ruleName = "$DisplayName-$Port-$Protocol"
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        if ($existingRule) {
            Set-NetFirewallRule -DisplayName $ruleName -Enabled True
            Write-Log -Message "Règle de pare-feu '$ruleName' mise à jour." -LogFile $LogFilePath
        } 
        else {
            New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol $Protocol -LocalPort $Port -Action Allow -RemoteAddress $RemoteAddresses
            Write-Log -Message "Règle de pare-feu '$ruleName' créée pour autoriser $Protocol sur le port $Port." -LogFile $LogFilePath
        }
        
        return $true
    }
    catch {
        Write-Log -Message "ERREUR lors de l'ouverture du port $Port: $_" -LogFile $LogFilePath -IsError
        return $false
    }
}

# Exporter les fonctions du module
Export-ModuleMember -Function Configure-Firewall, Open-FirewallPort
