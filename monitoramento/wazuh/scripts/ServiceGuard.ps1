##### Agendamento do script #####
# $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-ExecutionPolicy Bypass -File "C:\Tools\Scripts\ServiceGuard.ps1"' -WorkingDirectory "C:\Tools\Scripts"
# $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)
# $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
# Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "ServiceGuard" -Description "Monitora e reinicia serviços importantes"

# Lista de serviços a monitorar
$servicesOfInterest = @("EventLog", "WazuhSvc")
$logFile = "C:\Tools\Scripts\ServiceGuard.log"

# Força cultura US para garantir datas como "Jan"
$culture = [System.Globalization.CultureInfo]::InvariantCulture


function Write-Log {
    param (
        [string]$Path,
        [string]$Message
    )

    try {
        $fs = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::Append,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::ReadWrite
        )

        $sw = New-Object System.IO.StreamWriter($fs)
        $sw.WriteLine($Message)
        $sw.Flush()
        $sw.Close()
        $fs.Close()
    }
    catch {
        Write-Host "Erro ao escrever no log: $($_.Exception.Message)" -ForegroundColor Red
    }
}


foreach ($serviceName in $servicesOfInterest) {

    $serviceObj = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($serviceObj) {

        if ($serviceObj.Status -ne 'Running') {

            Write-Host "O servico $serviceName esta parado." -ForegroundColor Yellow

            Start-Service -Name $serviceName -ErrorAction SilentlyContinue

            # Aguarda atualização do status
            Start-Sleep -Seconds 5

            $newStatus = (Get-Service -Name $serviceName).Status

            if ($newStatus -eq 'Running') {

                # FORMATO SYSLOG: MMM dd HH:mm:ss HOST TAG: MSG
                $timestamp = (Get-Date).ToString("MMM dd HH:mm:ss", $culture)
                $hostname  = $env:COMPUTERNAME

                $msg = "$timestamp $hostname ServiceGuard: CRITICO: O servico $serviceName estava PARADO e foi REINICIADO."

                Write-Host "Escrevendo no log:" -ForegroundColor Green
                Write-Host $msg -ForegroundColor Blue

                Write-Log -Path $logFile -Message $msg
            }
        }
    }
}
