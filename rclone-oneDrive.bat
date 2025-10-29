@echo off
:: ==========================================================
:: Backup incremental avanzado de OneDrive con rclone
:: Autor: David M.
:: Fecha: %date% %time%
:: ==========================================================

:: === CONFIGURACIÓN PERSONALIZADA ===
set REMOTE_NAME=remoteOneDrive
set DEST_DIR=D:\InfoWeb-OneDrive\oneDrive
set LOG_DIR=D:\InfoWeb-OneDrive\logs
set BACKUP_DIR=D:\InfoWeb-OneDrive\_incrementales\%date:~-4,4%-%date:~-10,2%-%date:~-7,2%



set ZIP_FILE=%BACKUP_DIR%.zip
set LOG_FILE=%LOG_DIR%\onedrive_%date:~-4,4%-%date:~-10,2%-%date:~-7,2%.log
set RETENTION_DAYS=30

:: === INICIO DEL SCRIPT ===
echo ==========================================================
echo Iniciando backup incremental de OneDrive - %date% %time%
echo ==========================================================
echo.

:: Crear carpetas necesarias
if not exist "%DEST_DIR%" mkdir "%DEST_DIR%"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

:: === SINCRONIZAR DATOS (incremental) ===
echo [1/4] Ejecutando sincronizacion con OneDrive...
C:\rclone\rclone.exe sync %REMOTE_NAME%: "%DEST_DIR%" ^
  --backup-dir "%BACKUP_DIR%" ^
  --onedrive-delta ^
  --create-empty-src-dirs ^
  --fast-list ^
  --log-file "%LOG_FILE%" ^
  --log-level INFO ^
  --update ^
  --progress ^
  --ignore-size ^
  --tpslimit 10 ^
  --retries 3 ^
  --low-level-retries 5

if %ERRORLEVEL% neq 0 (
    echo [ERROR] Falla durante la sincronizacion. Codigo: %ERRORLEVEL%
    echo [ERROR] Backup fallido. >> "%LOG_FILE%"
    goto :error
)

:: === VERIFICACIÓN DE INTEGRIDAD ===
echo [2/4] Verificando integridad del backup...
C:\rclone\rclone.exe check %REMOTE_NAME%: "%DEST_DIR%" --one-way --log-file "%LOG_FILE%" --log-level INFO
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Fallo en verificacion de integridad. Codigo: %ERRORLEVEL%
    echo [ERROR] Inconsistencia detectada. >> "%LOG_FILE%"
    goto :error
)

:: === COMPRESIÓN DEL INCREMENTAL DEL DÍA ===
echo [3/4] Comprimiendo respaldo incremental del dia...
powershell -Command "Compress-Archive -Path '%BACKUP_DIR%\*' -DestinationPath '%ZIP_FILE%' -Force"
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Fallo al comprimir incremental. >> "%LOG_FILE%"
    goto :error
)

:: === LIMPIEZA AUTOMÁTICA DE ARCHIVOS ANTIGUOS ===
echo [4/4] Limpiando backups y logs antiguos (>%RETENTION_DAYS% días)...
forfiles /p "%LOG_DIR%" /s /m *.log /d -%RETENTION_DAYS% /c "cmd /c del @path"
forfiles /p "%DEST_DIR%\_incrementales" /d -%RETENTION_DAYS% /c "cmd /c rd /s /q @path"
echo Limpieza completada. >> "%LOG_FILE%"

:: === FINALIZACIÓN EXITOSA ===
echo [OK] Backup completado correctamente. >> "%LOG_FILE%"
echo Backup completado correctamente a las %time%.
echo ==========================================================
exit /b 0

:: === MANEJO DE ERRORES ===
:error
echo [ERROR] Se detecto un problema durante el backup. >> "%LOG_FILE%"
exit /b 1
