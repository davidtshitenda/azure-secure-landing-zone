Install-WindowsFeature -Name Web-Server -IncludeManagementTools
Set-Content -Path "C:\inetpub\wwwroot\index.html" -Value "<h1>Secure landing zone web tier: $env:COMPUTERNAME</h1>"