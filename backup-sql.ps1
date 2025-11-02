# Script completo de configuraciOn de backup para Windows Server 2022 con sistema de logging

# FunciOn para escribir logs
function Write-Log {
    param(
        [string]$Message,
        [string]$Type = "INFO",
        [string]$LogPath = "C:\Windows\Logs\Backup-Setup.log"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Type] $Message"
    
    # Escribir en archivo de log
    Add-Content -Path $LogPath -Value $logEntry
    
    # Mostrar en consola con colores
    switch ($Type) {
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "INFO" { Write-Host $logEntry -ForegroundColor Cyan }
        default { Write-Host $logEntry -ForegroundColor White }
    }
}

# Iniciar log
Write-Log "=== INICIO CONFIGURACION WINDOWS SERVER BACKUP ===" "INFO"

# 1. Verificar e instalar Windows Server Backup
Write-Log "Verificando instalaciOn de Windows Server Backup..." "INFO"
$feature = Get-WindowsFeature -Name Windows-Server-Backup

if ($feature.InstallState -ne "Installed") {
    Write-Log "Instalando Windows Server Backup..." "WARNING"
    try {
        Install-WindowsFeature -Name Windows-Server-Backup -IncludeManagementTools
        Write-Log "Windows Server Backup instalado correctamente" "SUCCESS"
    } catch {
        Write-Log "Error al instalar Windows Server Backup: $($_.Exception.Message)" "ERROR"
        exit 1
    }
} else {
    Write-Log "Windows Server Backup ya está instalado" "SUCCESS"
}

# 2. Importar el mOdulo
try {
    Import-Module -Name WindowsServerBackup -Force
    Write-Log "MOdulo WindowsServerBackup cargado exitosamente" "SUCCESS"
} catch {
    Write-Log "No se pudo cargar el mOdulo WindowsServerBackup: $($_.Exception.Message)" "ERROR"
    exit 1
}

# 3. Verificar comandos disponibles
Write-Log "Verificando disponibilidad de comandos de backup..." "INFO"

$wbCommands = @(
    "Get-WBPolicy", "New-WBPolicy", "Get-WBVolume", 
    "Add-WBVolume", "Get-WBDisk", "New-WBBackupTarget", 
    "Set-WBSchedule", "Set-WBPolicy"
)

foreach ($cmd in $wbCommands) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Log "Comando disponible: $cmd" "SUCCESS"
    } else {
        Write-Log "Comando NO disponible: $cmd" "ERROR"
    }
}

# 4. Mostrar discos disponibles
Write-Log "Enumerando discos disponibles en el sistema..." "INFO"
$disks = Get-Disk | Select-Object Number, Size, FriendlyName, PartitionStyle
foreach ($disk in $disks) {
    Write-Log "Disco $($disk.Number): $([math]::Round($disk.Size/1GB,2)) GB - $($disk.PartitionStyle)" "INFO"
}

# 5. Configurar backup automático
Write-Log "Iniciando configuraciOn de backup automático..." "INFO"

try {
    # Crear polItica de backup diario
    $policy = New-WBPolicy
    Write-Log "PolItica de backup creada" "SUCCESS"

    # Agregar volumen del sistema
    $volume = Get-WBVolume -VolumePath "C:"
    Add-WBVolume -Policy $policy -Volume $volume
    Write-Log "Volumen C: agregado a la polItica de backup" "SUCCESS"

    # Agregar estado del sistema
    Add-WBSystemState -Policy $policy
    Write-Log "Estado del sistema agregado a la polItica de backup" "SUCCESS"

    # Buscar discos disponibles (excluyendo C:)
    $availableDisks = Get-WBDisk | Where-Object { 
        $_.DiskNumber -ne 0 -and $_.Disksize -gt 1GB
    }

    if ($availableDisks.Count -eq 0) {
        Write-Log "No se encontraron discos adicionales para el backup" "ERROR"
        Write-Log "Conecte un disco USB externo o agregue un disco duro adicional" "WARNING"
        Write-Log "Los backups completos requieren un disco diferente al del sistema (C:)" "WARNING"
        exit 1
    }

    # Usar el primer disco disponible
    $backupDisk = $availableDisks[0]
    $backupLocation = New-WBBackupTarget -Disk $backupDisk
    Add-WBBackupTarget -Policy $policy -Target $backupLocation
    Write-Log "Destino de backup configurado en disco: $($backupDisk.DiskNumber)" "SUCCESS"

    # Programar backup diario a las 22:00
    Set-WBSchedule -Policy $policy -Schedule "22:00"
    Write-Log "Backup programado para ejecutarse diariamente a las 22:00" "SUCCESS"

    # Aplicar la polItica
    Set-WBPolicy -Policy $policy -Force
    Write-Log "PolItica de backup aplicada exitosamente" "SUCCESS"
    
    Write-Log "ConfiguraciOn de backup completada exitosamente" "SUCCESS"
    Write-Log "Frecuencia: Diariamente" "INFO"
    Write-Log "Hora: 22:00" "INFO"
    Write-Log "Destino: Disco $($backupDisk.DiskNumber)" "INFO"
    Write-Log "Incluye: Volumen C: + Estado del sistema" "INFO"

} catch {
    Write-Log "Error en la configuraciOn del backup: $($_.Exception.Message)" "ERROR"
    Write-Log "Detalles del error: $($_.Exception.StackTrace)" "ERROR"
}

# 6. Mostrar informaciOn final
Write-Log "Obteniendo informaciOn final de la configuraciOn..." "INFO"
try {
    $currentPolicy = Get-WBPolicy
    Write-Log "PolItica activa configurada: $($currentPolicy.PolicyName)" "SUCCESS"
} catch {
    Write-Log "No se pudo recuperar la polItica actual" "WARNING"
}

# Finalizar log
Write-Log "=== FIN CONFIGURACION WINDOWS SERVER BACKUP ===" "INFO"
Write-Log "Log guardado en: C:\Windows\Logs\Backup-Setup.log" "INFO"