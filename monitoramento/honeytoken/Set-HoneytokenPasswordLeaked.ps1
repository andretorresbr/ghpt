# Este script deve ser executado em PowerShell v5
Add-Type -AssemblyName System.Web

# Define o nome da conta honeypot
$nomeConta = "svc_wkstasks"
$descricao = "(senha test3@tar3f4$12345678) Execucao de tarefas agendadas em estacoes de trabalho."
$dn = "OU=Contas de Servico,OU=Tier2,DC=CORP,DC=LOCAL"
$dominio = "CORP.LOCAL"

#Criação da senha
Write-Host "[INFO] Definindo a senha da conta $nomeConta" -ForegroundColor Yellow
$minLength = 45 ## número de caracteres
$maxLength = 50 ## número de caracteres
$length = Get-Random -Minimum $minLength -Maximum $maxLength
$nonAlphaChars = 5
$password = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)
$secPw = ConvertTo-SecureString -String $password -AsPlainText -Force

# Criação da conta de serviço com a senha na descrição
Write-Host "[INFO] Criando a conta $nomeConta " -ForegroundColor Yellow
New-ADuser -Name $nomeConta -DisplayName $nomeConta -AccountPassword $secPw -Path $dn -Enabled $true -UserPrincipalName ("$nomeConta@" + $dominio) -SamAccountName $nomeConta -PasswordNeverExpires $true -Description $descricao

# Seta a conta com "Does not require Kerberos pre-auth" (AS-REP Roasting)

# Simula logons para a conta $nomeConta
Write-Host "[INFO] Simulando logons para a conta $nomeConta" -ForegroundColor Yellow
for ($i = 1; $i -le $length-10; $i++) {
	$credLog = New-Object System.Management.Automation.PSCredential("CORP\$nomeConta", $secPw)
    Enter-PSSession -ComputerName "WKJSKAJKDJFDF" -Credential $credLog -ErrorAction Ignore
}
Write-Host "[INFO] Valor de logonCount da conta $nomeConta" -ForegroundColor Green
Get-ADUser -Identity $nomeConta -Properties logonCount | Select-Object Name, logonCount
