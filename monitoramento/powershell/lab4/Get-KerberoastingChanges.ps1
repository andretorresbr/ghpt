# Janela de observação dos logs (em horas)
$StartTime = (Get-Date).AddHours(-1)

# Extrai o nome do script sem a extensão
$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
# Define o path do script
$TranscriptFile = "$PSScriptRoot\$ScriptName`_execution.txt"
# Inicia o log de execução do script
Start-Transcript -Path $TranscriptFile -Force

# Retrieve a list of all domain controllers in the domain
Write-Host "Obtendo lista de Domain Controllers do dominio..." -ForegroundColor Green
$DomainControllers = Get-ADDomainController -Filter *

# Inicializa um array de achados
$AllLogs = @()

foreach ($DC in $DomainControllers) {
    Write-Host "Analisando logs do $($DC.HostName)..." -ForegroundColor Yellow
    try {
        $Logs = Get-WinEvent -ComputerName $DC.HostName -FilterHashtable @{LogName='Security'; Id=5136; StartTime=$StartTime} | Where-Object { $_.Message -match 'LDAP Display Name:\s*servicePrincipalName' -and $_.Message -notmatch 'Account Name:\s*SYSTEM'}
        $AllLogs += $Logs
    } catch {
        Write-Host "Erro ao consultar o $($DC.HostName): $_" -ForegroundColor Red
    }
}

if ($AllLogs.Count -ne 0)
{
    $AllLogs
    $Message = "" + $AllLogs.Count + " alteração(ões) de SPN de conta(s) encontrada(s)`n`n"
    foreach ($Log in $AllLogs)
    {
        $Message += @"
💻 <b>Origem do log</b>: $($Log.MachineName)
📆 <b>Data/hora do log</b>: $($Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss"))
👤 <b>Usuário que executou</b>: $($Log.Properties[3].Value)
⚙️ <b>Conta com SPN alvo</b>: $($Log.Properties[8].Value)


"@
    }
    Write-Host "Enviando notificação via Telegram..." -ForegroundColor Green
    . .\Send-TelegramNotification.ps1
    Send-TelegramNotification -Source $env:COMPUTERNAME -Title "Alteração de SPN de conta detectada!" -Message $Message
} else
{
    Write-Host "Não foram encontrados logs." -ForegroundColor Yellow
}

Stop-Transcript
