# Script completo de configuracion de backup para Windows Server 2022 con sistema de logging y NAS

# Funcion para escribir logs
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

# Funcion para configurar backup en NAS
function Configure-NASBackup {
    param(
        [string]$NASPath,
        [string]$Username,
        [string]$Password,
        [string]$BackupTime = "02:00"
    )

    Write-Log "=== CONFIGURACIoN BACKUP EN NAS ===" "INFO"

    # 1. Verificar formato de ruta NAS
    if ($NASPath -notlike "\\*") {
        Write-Log "Formato de ruta incorrecto. Debe ser: \\servidor\carpeta" "ERROR"
        return $false
    }

    # 2. Crear credenciales seguras
    try {
        $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ($Username, $securePassword)
        Write-Log "Credenciales creadas para: $Username" "SUCCESS"
    } catch {
        Write-Log "Error creando credenciales: $($_.Exception.Message)" "ERROR"
        return $false
    }

    # 3. Verificar permisos de escritura en NAS
    Write-Log "Verificando permisos de escritura en NAS..." "INFO"
    $testFile = Join-Path $NASPath "test_permissions.txt"
    try {
        "Test de permisos $(Get-Date)" | Out-File -FilePath $testFile -Encoding UTF8 -Force
        Remove-Item -Path $testFile -Force
        Write-Log "Permisos de escritura OK en NAS" "SUCCESS"
    } catch {
        Write-Log "Sin permisos de escritura en NAS: $($_.Exception.Message)" "ERROR"
        return $false
    }

    # 4. Calcular espacio necesario
    $systemDrive = Get-WBVolume -VolumePath "C:"
    $usedSpaceGB = [math]::Round(($systemDrive.UsedSpace / 1GB), 2)
    Write-Log "Espacio usado en C:: $usedSpaceGB GB" "INFO"
    Write-Log "Espacio recomendado en NAS: $([math]::Round($usedSpaceGB * 1.5)) GB" "INFO"

    # 5. Configurar política de backup
    try {
        $policy = New-WBPolicy
        
        # Agregar elementos al backup
        Add-WBVolume -Policy $policy -Volume (Get-WBVolume -VolumePath "C:")
        Add-WBSystemState -Policy $policy
        
        # Configurar NAS como destino
        $backupLocation = New-WBBackupTarget -NetworkPath $NASPath -Credential $credential
        Add-WBBackupTarget -Policy $policy -Target $backupLocation
        
        # Programar y aplicar
        Set-WBSchedule -Policy $policy -Schedule $BackupTime
        Set-WBPolicy -Policy $policy -Force
        
        Write-Log "BACKUP NAS CONFIGURADO EXITOSAMENTE" "SUCCESS"
        Write-Log "Destino: $NASPath" "INFO"
        Write-Log "Horario: $BackupTime 2:00 AM" "INFO"
        Write-Log "Backup completo del sistema" "INFO"
        
        return $true
        
    } catch {
        Write-Log "Error configurando backup: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Iniciar log
Write-Log "=== INICIO CONFIGURACIoN WINDOWS SERVER BACKUP CON NAS ===" "INFO"

# 1. Verificar e instalar Windows Server Backup
Write-Log "Verificando instalacion de Windows Server Backup..." "INFO"
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

# 2. Importar el modulo
try {
    Import-Module -Name WindowsServerBackup -Force
    Write-Log "Modulo WindowsServerBackup cargado exitosamente" "SUCCESS"
} catch {
    Write-Log "No se pudo cargar el modulo WindowsServerBackup: $($_.Exception.Message)" "ERROR"
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

# 4. Mostrar discos disponibles (para referencia)
Write-Log "Enumerando discos disponibles en el sistema..." "INFO"
$disks = Get-Disk | Select-Object Number, Size, FriendlyName, PartitionStyle
foreach ($disk in $disks) {
    Write-Log "Disco $($disk.Number): $([math]::Round($disk.Size/1GB,2)) GB - $($disk.PartitionStyle)" "INFO"
}

# 5. CONFIGURACIoN PRINCIPAL - ELEGIR ENTRE NAS O DISCO LOCAL
Write-Log "=== SELECCIoN DE DESTINO DE BACKUP ===" "INFO"
Write-Log "1. Backup en NAS (Recomendado para produccion)" "INFO"
Write-Log "2. Backup en disco local (Para testing/emergencias)" "INFO"

# Configuracion del NAS - MODIFICA ESTOS VALORES CON TUS DATOS
$nasConfig = @{
    NASPath    = "\\192.168.10.25\backups_servidor"  # CAMBIA: IP/ruta de tu NAS
    Username   = "Chapulco"                             # CAMBIA: Usuario del NAS
    Password   = 'cIntel$2024$Eucomb'                       # CAMBIA: Password del NAS
    BackupTime = "02:00"                             # Hora de backup (2:00 AM)
}

Write-Log "Intentando configuracion en NAS: $($nasConfig.NASPath)" "INFO"

# Intentar configuracion en NAS primero
$nasSuccess = Configure-NASBackup @nasConfig

if (-not $nasSuccess) {
    Write-Log "=== FALLBACK A DISCO LOCAL ===" "WARNING"
    Write-Log "No se pudo configurar NAS, intentando con disco local..." "WARNING"
    
    try {
        # Crear política de backup diario
        $policy = New-WBPolicy
        Write-Log "Política de backup creada" "SUCCESS"

        # Agregar volumen del sistema
        $volume = Get-WBVolume -VolumePath "C:"
        Add-WBVolume -Policy $policy -Volume $volume
        Write-Log "Volumen C: agregado a la política de backup" "SUCCESS"

        # Agregar estado del sistema
        Add-WBSystemState -Policy $policy
        Write-Log "Estado del sistema agregado a la política de backup" "SUCCESS"

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

        # Programar backup diario a las 02:00 (2:00 AM)
        Set-WBSchedule -Policy $policy -Schedule "02:00"
        Write-Log "Backup programado para ejecutarse diariamente a las 02:00" "SUCCESS"

        # Aplicar la política
        Set-WBPolicy -Policy $policy -Force
        Write-Log "Política de backup aplicada exitosamente" "SUCCESS"
        
        Write-Log "Configuracion de backup completada exitosamente EN DISCO LOCAL" "SUCCESS"
        Write-Log "Frecuencia: Diariamente" "INFO"
        Write-Log "Hora: 02:00 (2:00 AM)" "INFO"
        Write-Log "Destino: Disco $($backupDisk.DiskNumber)" "INFO"
        Write-Log "Incluye: Volumen C: + Estado del sistema" "INFO"

    } catch {
        Write-Log "Error en la configuracion del backup local: $($_.Exception.Message)" "ERROR"
        Write-Log "Detalles del error: $($_.Exception.StackTrace)" "ERROR"
    }
}

# 6. Mostrar informacion final
Write-Log "Obteniendo informacion final de la configuracion..." "INFO"
try {
    $currentPolicy = Get-WBPolicy
    Write-Log "Política activa configurada: $($currentPolicy.PolicyName)" "SUCCESS"
    
    # Mostrar detalles del destino
    $backupTargets = $currentPolicy.BackupTargets
    Write-Log "Destinos configurados: $($backupTargets.Count)" "INFO"
    foreach ($target in $backupTargets) {
        Write-Log "  - $($target.TargetPath)" "SUCCESS"
    }
    
} catch {
    Write-Log "No se pudo recuperar la política actual" "WARNING"
}

# 7. Verificacion de la programacion
Write-Log "=== VERIFICACIoN DE PROGRAMACIoN ===" "INFO"
try {
    $scheduledTasks = Get-ScheduledTask -TaskName "*Microsoft*Windows*Backup*" | Where-Object {$_.State -eq "Ready"}
    if ($scheduledTasks) {
        Write-Log "Tareas de backup programadas:" "SUCCESS"
        foreach ($task in $scheduledTasks) {
            Write-Log "  - $($task.TaskName): $($task.State)" "INFO"
        }
    } else {
        Write-Log "No se encontraron tareas de backup programadas" "WARNING"
    }
} catch {
    Write-Log "No se pudieron verificar las tareas programadas" "WARNING"
}

# Finalizar log
Write-Log "=== FIN CONFIGURACIoN WINDOWS SERVER BACKUP ===" "INFO"
Write-Log "Log guardado en: C:\Windows\Logs\Backup-Setup.log" "INFO"
Write-Log "RECUERDA: Modifica las credenciales del NAS en el script con tus datos reales" "WARNING"