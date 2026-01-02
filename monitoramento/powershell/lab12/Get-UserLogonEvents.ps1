# Janela de observação dos logs (em horas)
$StartTime = (Get-Date).AddHours(-1)

# Extrai o nome do script sem a extensão
$ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
# Define o path do script
$TranscriptFile = "$PSScriptRoot\$ScriptName`_execution.txt"
# Inicia o log de execução do script
Start-Transcript -Path $TranscriptFile -Force


# Retrieve a list of all domain controllers in the domain
Write-Host "Obtendo lista de servidores Tier 0 do dominio (grupo T0 Servers)..." -ForegroundColor Green
#$Tier0Servers = Get-ADGroupMember -Identity "T0 Servers"
$Tier0Servers = Get-ADComputer -Identity CORP-DC

# Inicializa um array de achados
$AllLogsRDP = @()
$AllLogsWinRM = @()
$AllLogsConsole = @()

foreach ($Server in $Tier0Servers) {
    Write-Host "Analisando logs do $($Server.name)..." -ForegroundColor Yellow
    try {
        # Obtém logs de logon via RDP
        $LogsRDP = Get-WinEvent -ComputerName $Server.name -FilterHashtable @{LogName='Microsoft-Windows-TerminalServices-LocalSessionManager/Operational'; Id=21; StartTime=$StartTime} -ErrorAction SilentlyContinue | Where-Object { $_.Message -match 'Remote Desktop Services: Session logon succeeded' }
        $AllLogsRDP += $LogsRDP

        # Obtém logs de logon via WinRM
        $LogsWinRM = Get-WinEvent -ComputerName $Server.name -FilterHashtable @{LogName='Microsoft-Windows-WinRM/Operational'; Id=91; StartTime=$StartTime} -ErrorAction SilentlyContinue | Where-Object { $_.Message -match 'Creating WSMan shell on server with ResourceUri' }
        $AllLogsWinRM += $LogsWinRM

        $LogsConsole = Get-WinEvent -ComputerName $Server.name -FilterHashtable @{LogName='Security'; Id=4624; StartTime=$StartTime} -ErrorAction SilentlyContinue | Where-Object { $_.Message -match 'Logon Type:\s*2'}
        $AllLogsConsole += $LogsConsole
    } catch {
        Write-Host "Erro ao consultar o $($Server.name): $_" -ForegroundColor Red
    }
}

# Para eventos RDP, se houver logs
if ($AllLogsRDP.Count -ne 0)
{
    $AllLogsRDP
    foreach ($Log in $AllLogsRDP)
    {
        $Message = @"


"@

		# Extrai o usuário removendo o prefixo do domínio (ex: CORP\usuario)
		$Actor = $Log.Properties[0].Value.Split('\')[-1]

		$Message += @"
💻 <b>Origem do log</b>: $($Log.MachineName)
📆 <b>Data/hora do log</b>: $($Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss"))
👤 <b>Usuário que logou</b>: $Actor
🖧 <b>IP de origem</b>: $($Log.Properties[2].Value)


"@

        Write-Host "Enviando notificação direta via Telegram..." -ForegroundColor Green
        . .\Send-TelegramNotification.ps1
        Send-DirectTelegramNotification -Source $env:COMPUTERNAME -Title "Logon RDP detectado!" -Message $Message -SendTo $Actor
    }
} else
{
    Write-Host "Não foram encontrados logons RDP." -ForegroundColor Yellow
}

# Para eventos WinRM, se houver logs
if ($AllLogsWinRM.Count -ne 0)
{
    $AllLogsWinRM
    foreach ($Log in $AllLogsWinRM)
    {
        $Actor = $null
        $ip = $null
        $Message = @"

"@

        if ($Log.Message -match '\(([^)]+)\sclientIP:')
        {
            $Actor = $matches[1].Split('\')[-1]  # Extrai o usuário usando regex, retirando o CORP\
        }
        if ($Log.Message -match 'clientIP:\s([\d\.]+)')
        {
            $ip = $matches[1]  # Extract the IP address
        }
        $Message += @"
💻 <b>Origem do log</b>: $($Log.MachineName)
📆 <b>Data/hora do log</b>: $($Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss"))
👤 <b>Usuário que logou</b>: $Actor
🖧 <b>IP de origem</b>: $ip


"@
        Write-Host "Enviando notificação direta via Telegram..." -ForegroundColor Green
        . .\Send-TelegramNotification.ps1
        Send-DirectTelegramNotification -Source $env:COMPUTERNAME -Title "Logon WinRM detectado!" -Message $Message -SendTo $Actor
    }
} else
{
    Write-Host "Não foram encontrados logons WinRM." -ForegroundColor Yellow
}

# Para eventos de console, se houver logs
if ($AllLogsConsole.Count -ne 0)
{
    $AllLogsConsole
    $PreviousLog = $null
    $Message = @"


"@

    foreach ($Log in $AllLogsConsole)
    {
        $Actor = $Log.Properties[5].Value
        $Message = ""

        if ( ($null -eq $PreviousLog) -or ( $PreviousLog.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss") -ne $Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss")) )
        {
            $Message += @"
💻 <b>Origem do log</b>: $($Log.MachineName)
📆 <b>Data/hora do log</b>: $($Log.TimeCreated.ToString("dd/MM/yyyy HH:mm:ss"))
👤 <b>Usuário que logou</b>: $Actor


"@
        }
        
        $previousLog = $Log

        if ($Message -ne "")
        {
            Write-Host "Enviando notificação direta via Telegram..." -ForegroundColor Green
            . .\Send-TelegramNotification.ps1
            Send-DirectTelegramNotification -Source $env:COMPUTERNAME -Title "Logon via console detectado!" -Message $Message -SendTo $Actor           
        }
    } 
} else
{
    Write-Host "Não foram encontrados logons via console." -ForegroundColor Yellow
}

Stop-Transcript
