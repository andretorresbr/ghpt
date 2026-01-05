# Inspirado no projeto https://github.com/Blumira/Kerberoast-Detection

Add-Type -AssemblyName System.Web

# Define o nome da conta honeypot para Kerberoasting
$nomeContaKerb = "svc_mssqladmin"
$spnContaKerb = "MSSQLSvc/srv-mssql-prod.corp.local"
$descriptionKerb = "Conta administrativa dos servidores MSSQL Server"

# Define o nome da conta honeypot para AS-REP Roasting
$nomeContaAsRep = "svc_sqlsrvtest"
$descriptionAsRep = "Teste de conexao do MSSQL Server"


$maquinaNaoExistente = "WKS-19823923"


#Criação da senha
Write-Host "[INFO] Definindo a senha da conta $nomeContaKerb" -ForegroundColor Yellow
$minLength = 45 ## número de caracteres
$maxLength = 50 ## número de caracteres
$length = Get-Random -Minimum $minLength -Maximum $maxLength
$nonAlphaChars = 5
$passwordKerb = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)
$passwordAsRep = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphaChars)
$secPwKerb = ConvertTo-SecureString -String $passwordKerb -AsPlainText -Force
$secPwAsRep = ConvertTo-SecureString -String $passwordAsRep -AsPlainText -Force

# Criação da conta de serviço sujeita a Kerberoasting
Write-Host "[INFO] Criando a conta $nomeContaKerb com SPN $spnContaKerb (sujeita a Kerberoasting)" -ForegroundColor Yellow
New-ADuser -Name $nomeContaKerb -DisplayName $nomeContaKerb -AccountPassword $secPwKerb -Path "OU=Contas de Servico,OU=Tier0,DC=CORP,DC=LOCAL" -Enabled $true -UserPrincipalName "$nomeContaKerb@CORP.LOCAL" -SamAccountName $nomeContaKerb -PasswordNeverExpires $true -ServicePrincipalNames $spnContaKerb -Description $descriptionKerb

# Criação da conta de serviço sujeita a AS-REP Roasting
Write-Host "[INFO] Criando a conta $nomeContaAsRep" -ForegroundColor Yellow
New-ADuser -Name $nomeContaAsRep -DisplayName $nomeContaAsRep -AccountPassword $secPwAsRep -Path "OU=Contas de Servico,OU=Tier0,DC=CORP,DC=LOCAL" -Enabled $true -UserPrincipalName "$nomeContaAsRep@CORP.LOCAL" -SamAccountName $nomeContaAsRep -PasswordNeverExpires $true -Description $descriptionAsRep

# Seta a conta com "Does not require Kerberos pre-auth" (AS-REP Roasting)
Write-Host "[INFO] Configurando a conta $nomeContaAsRep com Does not require Kerberos pre-authentication (sujeita a AS-REP Kerberoasting)" -ForegroundColor Yellow
Set-ADAccountControl -Identity $nomeContaAsRep -DoesNotRequirePreAuth $true

# Simula logons para a conta $nomeContaKerb
Write-Host "[INFO] Simulando logons para a conta $nomeContaKerb" -ForegroundColor Yellow
$length = Get-Random -Minimum 20 -Maximum 50
$credLog = New-Object System.Management.Automation.PSCredential("CORP\$nomeContaKerb", $secPwKerb)
for ($i = 1; $i -le $length; $i++) {
    Enter-PSSession -ComputerName $maquinaNaoExistente -Credential $credLog -ErrorAction Ignore
}
Write-Host "[INFO] Valor de logonCount da conta $nomeContaKerb" -ForegroundColor Green
Get-ADUser -Identity $nomeContaKerb -Properties logonCount | Select-Object Name, logonCount

# Simula logons para a conta $nomeContaAsRep
Write-Host "[INFO] Simulando logons para a conta $nomeContaAsRep" -ForegroundColor Yellow
$length = Get-Random -Minimum 20 -Maximum 50
$credLog = New-Object System.Management.Automation.PSCredential("CORP\$nomeContaAsRep", $secPwAsRep)
for ($i = 1; $i -le $length; $i++) {
    Enter-PSSession -ComputerName $maquinaNaoExistente -Credential $credLog -ErrorAction Ignore
}
Write-Host "[INFO] Valor de logonCount da conta $nomeContaAsRep" -ForegroundColor Green
Get-ADUser -Identity $nomeContaAsRep -Properties logonCount | Select-Object Name, logonCount


# Hardeniza as contas para não haver uso real
Write-Host "[INFO] Restringindo o logon da $nomeContaKerb a maquina nao existente $maquinaNaoExistente" -ForegroundColor Yellow
Set-ADUser -Identity $nomeContaKerb -LogonWorkstations $maquinaNaoExistente
Write-Host "[INFO] Restringindo o logon da $nomeContaAsRep a maquina nao existente $maquinaNaoExistente" -ForegroundColor Yellow
Set-ADUser -Identity $nomeContaAsRep -LogonWorkstations $maquinaNaoExistente

# Se restringir o horário de logon para ASREP Roasting, ele não funciona (KDC_ERR_CLIENT_REVOKED) e não é detectado
Write-Host "[INFO] Restringindo o horario de logon da $nomeContaKerb para nenhuma hora" -ForegroundColor Yellow
# Não permite o logon em hora alguma
$logonHours = New-Object byte[] 21
# Configura todas as horas para 0 (sem acesso)
for ($i = 0; $i -lt 21; $i++) {$logonHours[$i] = 0}
Set-ADUser -Identity $nomeContaKerb -Replace @{logonHours = $logonHours}

# Marca ambas como não podendo ser delegadas
Write-Host "[INFO] Restringindo a delegação nas contas $nomeContaKerb e $nomeContaAsRep" -ForegroundColor Yellow
Set-ADUser -Identity $nomeContaKerb -AccountNotDelegated $true
Set-ADUser -Identity $nomeContaAsRep -AccountNotDelegated $true
