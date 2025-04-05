# Script bootstrap minimal pour télécharger et exécuter le script d'installation complet
# Ce script est conçu pour être petit et tenir dans les limites de user_data d'AWS EC2

# Configurer TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Créer les dossiers nécessaires
New-Item -Path "C:\MT5" -ItemType Directory -Force | Out-Null
New-Item -Path "C:\MT5\logs" -ItemType Directory -Force | Out-Null

# Activer RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -Type DWord
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Installer AWS CLI
$awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
$awsCliInstaller = "C:\MT5\AWSCLIV2.msi"
Invoke-WebRequest -Uri $awsCliUrl -OutFile $awsCliInstaller
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $awsCliInstaller /quiet /norestart" -Wait

# Ajouter le chemin d'AWS CLI à l'environnement
$awsCliPath = "$env:ProgramFiles\Amazon\AWSCLIV2"
$env:Path += ";$awsCliPath;$awsCliPath\bin"

# Créer un fichier de log
$logFile = "C:\Windows\Temp\mt5_bootstrap.log"
function Write-Log {
    param ($message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "[$timestamp] $message" | Out-File -FilePath $logFile -Append
}

Write-Log "Début du script bootstrap"

# Attendre que AWS CLI soit disponible (parfois il faut un peu de temps après l'installation)
$retryCount = 0
$maxRetries = 5
while (-not (Get-Command aws -ErrorAction SilentlyContinue) -and $retryCount -lt $maxRetries) {
    Write-Log "AWS CLI non disponible, attente de 10 secondes (tentative $($retryCount+1)/$maxRetries)..."
    Start-Sleep -Seconds 10
    $retryCount++
    # Rafraîchir le PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path += ";$awsCliPath;$awsCliPath\bin"
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Log "ERREUR: AWS CLI n'est toujours pas disponible après $maxRetries tentatives."
    exit 1
}

# Télécharger le script complet depuis S3
$fullScriptPath = "C:\MT5\install-mt5-full.ps1"
Write-Log "Téléchargement du script complet depuis S3..."
try {
    aws s3 cp s3://ea-trading-bucket/scripts/install-mt5-full.ps1 $fullScriptPath
    if (Test-Path $fullScriptPath) {
        Write-Log "Script téléchargé avec succès vers $fullScriptPath"
        
        # Exécuter le script complet
        Write-Log "Exécution du script complet..."
        & $fullScriptPath
        Write-Log "Exécution du script complet terminée avec code de sortie: $LASTEXITCODE"
    } else {
        Write-Log "ERREUR: Le script n'a pas été téléchargé correctement."
    }
} catch {
    Write-Log "ERREUR lors du téléchargement ou de l'exécution du script: $_"
}

Write-Log "Fin du script bootstrap"
