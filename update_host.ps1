# Script to update GitHub hosts entries and configure DNS
# Self-elevate the script to run as Administrator
if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Running with administrator privileges." -ForegroundColor Green

# Download hosts content from Gitee
try {
    $hostsContent = Invoke-WebRequest -Uri "https://gitee.com/godfather1103/github-hosts/raw/master/hosts" -UseBasicParsing
    $githubHosts = $hostsContent.Content
    Write-Host "Successfully downloaded GitHub hosts content." -ForegroundColor Green
} catch {
    Write-Host "Failed to download GitHub hosts content: $_" -ForegroundColor Red
    exit 1
}

# Update hosts file
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$hostsFileContent = Get-Content -Path $hostsPath -Raw

# Check if GitHub hosts entries already exist
if ($hostsFileContent -match "# GitHub Host Start[\s\S]*?# GitHub Host End") {
    Write-Host "Existing GitHub hosts entries found. Removing them..." -ForegroundColor Yellow
    $hostsFileContent = $hostsFileContent -replace "# GitHub Host Start[\s\S]*?# GitHub Host End", ""
}

# Add new GitHub hosts entries
$hostsFileContent = $hostsFileContent.TrimEnd() + "`n`n" + $githubHosts

# Try multiple times to update the hosts file in case it's locked
$maxRetries = 3
$retryCount = 0
$success = $false

while (-not $success -and $retryCount -lt $maxRetries) {
    try {
        $hostsFileContent | Set-Content -Path $hostsPath -Force
        Write-Host "Hosts file updated successfully." -ForegroundColor Green
        $success = $true
    } catch {
        $retryCount++
        Write-Host "Failed to update hosts file (attempt $retryCount of $maxRetries): $_" -ForegroundColor Yellow
        
        if ($retryCount -lt $maxRetries) {
            Write-Host "Waiting 3 seconds before retrying..." -ForegroundColor Yellow
            Start-Sleep -Seconds 3
        } else {
            Write-Host "Could not update hosts file after $maxRetries attempts. Please close any applications that might be using the hosts file and try again." -ForegroundColor Red
        }
    }
}

# Flush DNS cache
try {
    Write-Host "Flushing DNS cache..." -ForegroundColor Yellow
    ipconfig /flushdns
    Write-Host "DNS cache flushed successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to flush DNS cache: $_" -ForegroundColor Red
}

# Configure DNS settings
try {
    Write-Host "Configuring DNS settings..." -ForegroundColor Yellow
    $netAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
    
    foreach ($adapter in $netAdapters) {
        Write-Host "Setting DNS for adapter: $($adapter.Name)" -ForegroundColor Yellow
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses ("8.8.8.8", "1.1.1.1")
    }
    
    Write-Host "DNS configured successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to configure DNS: $_" -ForegroundColor Red
}

# Flush DNS cache again
try {
    Write-Host "Flushing DNS cache again..." -ForegroundColor Yellow
    ipconfig /flushdns
    Write-Host "DNS cache flushed successfully." -ForegroundColor Green
} catch {
    Write-Host "Failed to flush DNS cache: $_" -ForegroundColor Red
}

Write-Host "All operations completed successfully!" -ForegroundColor Green
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 
