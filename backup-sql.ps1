# Script de Backup SQL Server Express - SIN COMPRESION
param(
    [string]$ServerInstance = "USER-PC\SQLEXPRESS",
    [string]$Database = "DBPAGOSLOTES"
)

$BackupPath = "D:\BackupsSQL\"
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"

Write-Host "=== INICIANDO BACKUP SQL EXPRESS ===" -ForegroundColor Green
Write-Host "Servidor: $ServerInstance" -ForegroundColor Yellow
Write-Host "Base de datos: $Database" -ForegroundColor Yellow
Write-Host "Nota: SQL Express no soporta compresion" -ForegroundColor Cyan

# Crear directorio si no existe
if (!(Test-Path $BackupPath)) {
    New-Item -ItemType Directory -Path $BackupPath -Force
    Write-Host "Directorio creado: $BackupPath" -ForegroundColor Cyan
}

# Verificar servicios SQL
try {
    Write-Host "Verificando servicios de SQL Server..." -ForegroundColor Yellow
    $sqlServices = Get-Service | Where-Object { 
        $_.Name -like "*SQL*" -and $_.Status -eq "Running" 
    }
    
    if ($sqlServices.Count -eq 0) {
        throw "No se encontraron servicios de SQL Server en ejecucion"
    } else {
        Write-Host "Servicios de SQL Server encontrados:" -ForegroundColor Green
        $sqlServices | ForEach-Object { 
            Write-Host "  - $($_.Name): $($_.Status)" -ForegroundColor White 
        }
    }
} catch {
    Write-Error "Error verificando SQL Server: $_"
    exit 1
}

# Verificar conexion a la base de datos
try {
    Write-Host "Verificando conexion a la base de datos..." -ForegroundColor Yellow
    $testQuery = "SELECT COUNT(*) as count FROM sys.databases WHERE name = '$Database'"
    $dbExists = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $testQuery -ErrorAction Stop
    
    if ($dbExists.count -eq 0) {
        throw "La base de datos '$Database' no existe en el servidor"
    }
    
    Write-Host "Conexion a la base de datos exitosa" -ForegroundColor Green
} catch {
    Write-Error "No se puede conectar a la base de datos: $_"
    
    # Mostrar bases de datos disponibles
    try {
        Write-Host "Bases de datos disponibles en el servidor:" -ForegroundColor Yellow
        $availableDBs = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "SELECT name FROM sys.databases WHERE database_id > 4" -ErrorAction SilentlyContinue
        $availableDBs | ForEach-Object { Write-Host "  - $($_.name)" -ForegroundColor White }
    } catch {
        Write-Host "No se pudieron listar las bases de datos disponibles" -ForegroundColor Red
    }
    
    exit 1
}

# Generar backup SIN COMPRESION (para SQL Express)
try {
    $BackupFile = "$BackupPath$Database`_$TimeStamp.bak"
    
    Write-Host "Iniciando backup de $Database..." -ForegroundColor Green
    Write-Host "Nota: Backup sin compresion (limite SQL Express)" -ForegroundColor Yellow
    
    # Backup SIN la opcion de compresion
    Backup-SqlDatabase -ServerInstance $ServerInstance -Database $Database -BackupFile $BackupFile
    
    Write-Host "Backup completado exitosamente" -ForegroundColor Green
    Write-Host "Archivo: $BackupFile" -ForegroundColor White
    Write-Host "Tamaño: $([math]::Round((Get-Item $BackupFile).Length/1MB, 2)) MB" -ForegroundColor Cyan
    
    # Verificar integridad del backup
    Write-Host "Verificando integridad del backup..." -ForegroundColor Yellow
    $verifyQuery = "RESTORE VERIFYONLY FROM DISK = '$BackupFile'"
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $verifyQuery
    
    Write-Host "Backup verificado correctamente" -ForegroundColor Green
    
} catch {
    Write-Error "Error durante el backup: $_"
    exit 1
}

Write-Host "=== BACKUP FINALIZADO CON EXITO ===" -ForegroundColor Green

