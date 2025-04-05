# Script pour télécharger le script d'installation complet vers S3
# À exécuter avant terraform apply

# Vérifier que AWS CLI est installé
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "AWS CLI n'est pas installé. Veuillez l'installer avant d'exécuter ce script."
    exit 1
}

# Définir les chemins
$scriptPath = "$PSScriptRoot\..\core\install-mt5.ps1"
$s3Path = "s3://ea-trading-bucket/scripts/install-mt5-full.ps1"

# Vérifier que le script existe
if (-not (Test-Path $scriptPath)) {
    Write-Host "Le script $scriptPath n'existe pas."
    exit 1
}

# Télécharger le script vers S3
Write-Host "Téléchargement du script vers $s3Path..."
aws s3 cp $scriptPath $s3Path

# Vérifier le résultat
if ($LASTEXITCODE -eq 0) {
    Write-Host "Le script a été téléchargé avec succès vers S3."
} else {
    Write-Host "Erreur lors du téléchargement du script vers S3."
    exit 1
}

Write-Host "Terminé. Vous pouvez maintenant exécuter 'terraform apply'."
