# Define the path to the text file with permitted servers
$UnconstrainedPermittedServersFile = ".\UnConstrainedDelegations_Permitidos.txt"
# Load the list of permitted servers from the file
$UnconstrainedPermittedServers = Get-Content -Path $UnconstrainedPermittedServersFile
# Define the path to the text file with permitted servers
$ConstrainedPermittedServersFile = ".\ConstrainedDelegations_Permitidos.txt"
# Load the list of permitted servers from the file
$ConstrainedPermittedServers = Get-Content -Path $ConstrainedPermittedServersFile

# Get all computers in the domain with unconstrained delegation
$computersWithUnconstrainedDelegation = Get-ADComputer -Filter {TrustedForDelegation -eq $true} -Properties TrustedForDelegation
$objectsWithConstrainedDelegation = Get-ADObject -Filter {msDS-AllowedToDelegateTo -ne "$null"} -Properties msDS-AllowedToDelegateTo


# Exclude Domain Controllers
$nonDomainControllers = $computersWithUnconstrainedDelegation | Where-Object {
    ($_ | Get-ADComputer -Properties PrimaryGroupID).PrimaryGroupID -ne 516
}

# Exclude permitted servers from the results
$UnconstrainedResult = $nonDomainControllers | Where-Object {
    -not ($_.Name -in $UnconstrainedPermittedServers)
}

$ConstrainedResult = $objectsWithConstrainedDelegation | Where-Object {
    -not ($_.Name -in $ConstrainedPermittedServers)
}

if ($ConstrainedResult -eq $null)
{
    $ConstrainedResult = 0
}
if ($UnconstrainedResult -eq $null)
{
    $UnconstrainedResult = 0
}

if (($UnconstrainedResult -ne 0))
{
    $UnconstrainedResult
    $Message = @"
O acesso administrativo a máquinas com essa configuração implica no potencial comprometimento do domínio.


"@

foreach ($Server in $UnconstrainedResult)
{
    $Message += @"
💻 <b>Servidor com Unconstrained Delegation configurado</b>: $($Server.DNSHostName)


"@
}
    Write-Host "Enviando notificação via Telegram..." -ForegroundColor Green
    . .\Send-TelegramNotification.ps1
    Send-TelegramNotification -Source $env:COMPUTERNAME -Title "Configuração de Unconstrained Delegation encontrada!" -Message $Message
} else
{
    Write-Host "Não foram encontradas Unconstrained Delegations fora da lista de permissão." -ForegroundColor Yellow
}

if ($ConstrainedResult -ne 0)
{
    $ConstrainedResult
    $Message = @"
Configuração de Constrained Delegation encontrada


"@

	foreach ($Server in $ConstrainedResult)
	{
		$ObjectName = (($Server.DistinguishedName -split ',')[0] -replace 'CN=', '')
		$DelegatedObject = (($Server."msDS-AllowedToDelegateTo" -split '/')[1] -split '\.' | Select-Object -First 1)

		$Message += @"
💻 <b>Objeto com Constrained Delegation configurado</b>: $($Server.DistinguishedName)
⚙️ <b>Delegação configurada para</b>: $($Server."msDS-AllowedToDelegateTo")
(caso o objeto $ObjectName seja comprometido, o objeto $DelegatedObject potencialmente também será)

"@
	}

    Write-Host "Enviando notificação via Telegram..." -ForegroundColor Green
    . .\Send-TelegramNotification.ps1
    Send-TelegramNotification -Source $env:COMPUTERNAME -Title "Configuração de Constrained Delegation encontrada!" -Message $Message
} else
{
    Write-Host "Não foram encontradas Constrained Delegations fora da lista de permissão." -ForegroundColor Yellow
}
