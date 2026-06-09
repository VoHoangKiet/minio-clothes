# ==============================================================================
# Script quan tri MinIO Docker tren Windows (PowerShell)
# Huong dan chay: .\scripts\manage.ps1 <lenh>
# ==============================================================================

param (
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet("up", "down", "restart", "logs", "status", "backup", "restore")]
    [string]$Action,

    [Parameter(Mandatory=$false, Position=1)]
    [string]$BackupFile
)

# 1. Kiem tra vi tri chay script (phai o thu muc goc chua docker-compose.yml)
if (!(Test-Path "docker-compose.yml")) {
    Write-Host "[LOI] Vui long chay script nay tu thu muc goc cua du an (thu muc chua docker-compose.yml)." -ForegroundColor Red
    Write-Host "Vi du: .\scripts\manage.ps1 up" -ForegroundColor Yellow
    exit 1
}

# 2. Load cac bien moi truong tu file .env
if (Test-Path ".env") {
    Write-Host "Dang tai cau hinh tu file .env..." -ForegroundColor Gray
    Get-Content ".env" | Where-Object { $_ -notmatch "^\s*#" -and $_ -match "=" } | ForEach-Object {
        $name, $value = $_ -split '=', 2
        $name = $name.Trim()
        $value = $value.Trim()
        [System.Environment]::SetEnvironmentVariable($name, $value)
    }
} else {
    Write-Host "[CANH BAO] Khong tim thay file .env. Se su dung cau hinh mac dinh." -ForegroundColor Yellow
}

# Lay cac bien cau hinh can thiet
$apiPort = [System.Environment]::GetEnvironmentVariable("MINIO_API_PORT")
$consolePort = [System.Environment]::GetEnvironmentVariable("MINIO_CONSOLE_PORT")
$volumes = [System.Environment]::GetEnvironmentVariable("MINIO_VOLUMES")
$rootUser = [System.Environment]::GetEnvironmentVariable("MINIO_ROOT_USER")

if ([string]::IsNullOrEmpty($apiPort)) { $apiPort = "9000" }
if ([string]::IsNullOrEmpty($consolePort)) { $consolePort = "9001" }
if ([string]::IsNullOrEmpty($volumes)) { $volumes = "./data" }
if ([string]::IsNullOrEmpty($rootUser)) { $rootUser = "minioadmin" }

# Duong dan tuyet doi thu muc du lieu
$absoluteVolumePath = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $volumes))

# 3. Xu ly cac lenh
switch ($Action) {
    "up" {
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        Write-Host "Khoi dong dich vu MinIO tren Docker..." -ForegroundColor Cyan
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        docker compose up -d
        
        Write-Host ""
        Write-Host "==================================================" -ForegroundColor Green
        Write-Host " Khoi dong thanh cong!" -ForegroundColor Green
        Write-Host " API Endpoint: http://localhost:$apiPort" -ForegroundColor Green
        Write-Host " Console UI:   http://localhost:$consolePort" -ForegroundColor Green
        Write-Host " Tai khoan:    $rootUser" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green
    }
    
    "down" {
        Write-Host "Dang dung cac container MinIO..." -ForegroundColor Yellow
        docker compose down
        Write-Host "Da dung va giai phong tai nguyen thanh cong." -ForegroundColor Green
    }
    
    "restart" {
        Write-Host "Dang khoi dong lai dich vu..." -ForegroundColor Cyan
        docker compose restart
        Write-Host "Da khoi dong lai thanh cong." -ForegroundColor Green
    }
    
    "logs" {
        Write-Host "Dang theo doi logs (nhan Ctrl+C de thoat)..." -ForegroundColor Gray
        docker compose logs -f
    }
    
    "status" {
        Write-Host "Trang thai cac container cua du an:" -ForegroundColor Cyan
        docker compose ps
    }
    
    "backup" {
        $backupDir = Join-Path (Get-Location) "backups"
        if (!(Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $zipFile = Join-Path $backupDir "minio-backup-$timestamp.zip"
        
        Write-Host "Dang tien hanh sao luu du lieu..." -ForegroundColor Cyan
        Write-Host "Thu muc nguon: $absoluteVolumePath" -ForegroundColor Gray
        Write-Host "File dich:     $zipFile" -ForegroundColor Gray
        
        if (Test-Path $absoluteVolumePath) {
            # Tam thoi dung container de dam bao du lieu khong bi ghi de khi dang zip
            Write-Host "Dang dung dich vu MinIO de dam bao tinh nhat quan du lieu..." -ForegroundColor Gray
            docker compose stop minio | Out-Null
            
            try {
                Compress-Archive -Path "$absoluteVolumePath\*" -DestinationPath $zipFile -Force
                Write-Host "Sao luu thanh cong!" -ForegroundColor Green
            }
            catch {
                Write-Host "[LOI] Khong the nen thu muc du lieu: $_" -ForegroundColor Red
            }
            finally {
                Write-Host "Dang khoi dong lai dich vu MinIO..." -ForegroundColor Gray
                docker compose start minio | Out-Null
            }
        } else {
            Write-Host "[CANH BAO] Thu muc du lieu $absoluteVolumePath chua duoc khoi tao hoac khong ton tai." -ForegroundColor Yellow
        }
    }
    
    "restore" {
        if ([string]::IsNullOrEmpty($BackupFile)) {
            # Tim file backup moi nhat trong thu muc backups
            $backupDir = Join-Path (Get-Location) "backups"
            if (Test-Path $backupDir) {
                $latestBackup = Get-ChildItem -Path $backupDir -Filter "*.zip" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if ($latestBackup) {
                    $BackupFile = $latestBackup.FullName
                }
            }
        }
        
        if ([string]::IsNullOrEmpty($BackupFile) -or !(Test-Path $BackupFile)) {
            Write-Host "[LOI] Khong tim thay file backup de phuc hoi." -ForegroundColor Red
            Write-Host "Vui long chi dinh duong dan file backup: .\scripts\manage.ps1 restore C:\path\to\backup.zip" -ForegroundColor Yellow
            exit 1
        }
        
        Write-Host "Chuan bi khoi phuc du lieu tu: $BackupFile" -ForegroundColor Cyan
        Write-Host "Thu muc dich: $absoluteVolumePath" -ForegroundColor Gray
        
        $confirmation = Read-Host "Canh bao: Hanh dong nay se thay the du lieu hien tai trong thu muc data. Ban co chac chan muon tiep tuc? (Y/N)"
        if ($confirmation -ne "Y" -and $confirmation -ne "y") {
            Write-Host "Da huy bo qua trinh khoi phuc." -ForegroundColor Yellow
            exit 0
        }
        
        # Dung container hoan toan truoc khi khoi phuc
        Write-Host "Dang dung cac container MinIO..." -ForegroundColor Gray
        docker compose down | Out-Null
        
        # Xoa du lieu cu
        if (Test-Path $absoluteVolumePath) {
            Write-Host "Dang xoa du lieu cu..." -ForegroundColor Gray
            Remove-Item -Path "$absoluteVolumePath\*" -Recurse -Force | Out-Null
        } else {
            New-Item -ItemType Directory -Path $absoluteVolumePath | Out-Null
        }
        
        try {
            Write-Host "Dang giai nen file backup..." -ForegroundColor Gray
            Expand-Archive -Path $BackupFile -DestinationPath $absoluteVolumePath -Force
            Write-Host "Khoi phuc du lieu thanh cong!" -ForegroundColor Green
            Write-Host "Dang khoi dong lai dich vu MinIO..." -ForegroundColor Gray
            docker compose up -d
        }
        catch {
            Write-Host "[LOI] Da xay ra loi khi khoi phuc du lieu: $_" -ForegroundColor Red
        }
    }
}
