# Lê o JSON que o Wazuh envia pelo STDIN
$InputJson = [Console]::In.ReadLine()
$AlertObj = $InputJson | ConvertFrom-Json

# Caminho do Log para Debug (Essencial para troubleshooting)
$LogFile = "C:\Program Files (x86)\ossec-agent\active-response\DisableUser.log"

# Função simples de Log
Function Write-Log {
    Param ([string]$Message)
    $Date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogFile -Value "[$Date] $Message"
}

try {
	Write-Log "Iniciando script."
    # Extrai o nome do usuário do JSON
    # O caminho depende da sua regra, mas geralmente para Windows Event Channel é:
    $TargetUser = $AlertObj.parameters.alert.data.win.eventdata.targetUserName

    Write-Log "Usuário extraído do alerta: $TargetUser"

    if ([string]::IsNullOrWhiteSpace($TargetUser) -or $TargetUser -eq "-") {
        Write-Log "ERRO: Usuário vazio ou inválido."
        exit
    }

    # --- LÓGICA DE DESABILITAR ---
    
    # Tratamento para remover domínio se vier no formato DOMINIO\Usuario
    if ($TargetUser -match "\\") {
        $TargetUser = $TargetUser.Split("\")[1]
    }
	
	# Adicione aqui os usuários que NUNCA devem ser bloqueados automaticamente
	$ExcludedUsers = @("administrator", "breaktheglass_da", "krbtgt")

    # Verifica se o usuário alvo está na lista (o operador -contains ignora maiúsculas/minúsculas)
    if ($ExcludedUsers -contains $TargetUser) {
        Write-Log "ALERTA: Ação cancelada. O usuário '$TargetUser' está na lista de proteção e NÃO será desabilitado."
        exit
    }

    # *** OPÇÃO B: Se for usuário Local ou comando legado (funciona na maioria)
    net user $TargetUser /active:no

    if ($LASTEXITCODE -eq 0) {
        Write-Log "SUCESSO: Usuário $TargetUser foi desabilitado."
    } else {
        Write-Log "FALHA: Erro ao tentar desabilitar $TargetUser. Código: $LASTEXITCODE"
    }

} catch {
    Write-Log "ERRO CRÍTICO: $($_.Exception.Message)"
}
