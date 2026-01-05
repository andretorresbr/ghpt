# Script em fase de testes, favor não alterar
$networkPath = "\\srv-fileserver\usuarios"
$driveLetter = "X:"
$username = "corp\svc_wkstasks"
$password = "test3@tar3f4$"

# Create a secure password
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force

# Create a PSCredential object
$credential = New-Object System.Management.Automation.PSCredential ($username, $securePassword)

# Remove o mapeamento, se já existir
if (Test-Path $driveLetter) {
    Write-Host "Drive $driveLetter ja existe. Removendo..."
    Remove-PSDrive -Name $driveLetter -Force -ErrorAction SilentlyContinue
}

# Mapeia o driver de rede
try {
    New-PSDrive -Name $driveLetter.TrimEnd(':') -PSProvider FileSystem -Root $networkPath -Credential $credential -Persist
    Write-Host "Drive $driveLetter mapeado com sucesso para $networkPath."
} catch {
    Write-Host "Falha para mapear o drive. Erro: $_"
}
