##### Agendamento do script #####
# $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-ExecutionPolicy Bypass -File "C:\Tools\Scripts\ServiceGuard.ps1"' -WorkingDirectory "C:\Tools\Scripts"
# $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)
# $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
# Register-ScheduledTask -Action $action -Trigger $trigger -Principal $principal -TaskName "ServiceGuard" -Description "Monitora e reinicia serviços importantes"

# Lista de serviços a monitorar
$servicesOfInterest = @("EventLog", "WazuhSvc")
$logFile = "C:\Tools\Scripts\ServiceGuard.log"

# Força cultura US para garantir datas como "Jan" (Wazuh exige inglês)
$culture = [System.Globalization.CultureInfo]::InvariantCulture

foreach ($serviceName in $servicesOfInterest) {
    $serviceObj = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($serviceObj) {
        if ($serviceObj.Status -ne 'Running') {
            Start-Service -Name $serviceName -ErrorAction SilentlyContinue
            
            # Pequena pausa para garantir que o status atualizou
            Start-Sleep -Seconds 2 
            
            $newStatus = (Get-Service -Name $serviceName).Status
            
            if ($newStatus -eq 'Running') {
                # FORMATO PADRÃO SYSLOG: MMM dd HH:mm:ss HOSTNAME PROGRAMA: MSG
                $timestamp = (Get-Date).ToString("MMM dd HH:mm:ss", $culture)
                $hostname = $env:COMPUTERNAME
                
                # Note a estrutura: DATA ESPAÇO HOST ESPAÇO TAG: MENSAGEM
                $msg = "$timestamp $hostname ServiceGuard: CRITICO: O servico $serviceName estava PARADO e foi REINICIADO."
                
                Add-Content -Path $logFile -Value $msg
            }
        }
    }
}
