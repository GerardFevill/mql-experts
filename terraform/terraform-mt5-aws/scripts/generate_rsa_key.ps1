# Script pour générer une paire de clés RSA au format PEM
# Ce script utilise OpenSSL pour générer une clé au format compatible avec AWS

# Créer le dossier keys s'il n'existe pas
$keysDir = "..\keys"
if (!(Test-Path -Path $keysDir)) {
    New-Item -ItemType Directory -Path $keysDir | Out-Null
    Write-Host "Dossier 'keys' créé."
}

# Nom de la clé
$keyName = "mt5-key-rsa"
$privateKeyPath = "$keysDir\$keyName.pem"
$publicKeyPath = "$keysDir\$keyName.pub"

# Vérifier si la clé existe déjà
if (Test-Path -Path $privateKeyPath) {
    Write-Host "La clé '$keyName' existe déjà."
    exit 0
}

# Générer la clé privée RSA
Write-Host "Génération de la clé privée RSA..."
openssl genrsa -out $privateKeyPath 2048

# Générer la clé publique correspondante au format OpenSSH
Write-Host "Génération de la clé publique..."
openssl rsa -in $privateKeyPath -pubout -out "$keysDir\$keyName.pub.pem"

# Convertir la clé publique au format accepté par AWS
Write-Host "Conversion de la clé publique au format OpenSSH..."
$pubKey = openssl rsa -in $privateKeyPath -pubout -outform DER | openssl base64 -A
$pubKey = "ssh-rsa " + $pubKey
$pubKey | Out-File -FilePath $publicKeyPath -Encoding ascii

Write-Host "Paire de clés RSA générée avec succès :"
Write-Host "Clé privée (format RSA PEM) : $privateKeyPath"
Write-Host "Clé publique (format OpenSSH) : $publicKeyPath"

# Afficher les premières lignes de la clé privée pour vérification
Write-Host "`nVérification du format de la clé privée:"
Get-Content $privateKeyPath -Head 2
Write-Host "..."
Get-Content $privateKeyPath -Tail 1
