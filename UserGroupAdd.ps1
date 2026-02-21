# Add-UsersToGroups.ps1
# Adds service accounts to specified Active Directory groups
# Requires: ActiveDirectory PowerShell module (RSAT)

#Requires -Modules ActiveDirectory

# --- Configuration ---
$Users = @(
    "svc-backup",
    "smb-backup",
    "wsus-backup",
    "iis-backup",
    "adfs-backup",
    "CertificateAuthority"
)

$Groups = @(
    "Admins",
    "IIS_USERS",
    "Remote Desktop Users",
    "Remote Management Users",
    "System Managed Accounts",
    "Print Operators",
    "Network Configuration Operators",
    "Backup Operators"
)

# --- Script ---
$ErrorActionPreference = "Continue"
$Results = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($Group in $Groups) {
    # Verify group exists
    try {
        $ADGroup = Get-ADGroup -Identity $Group -ErrorAction Stop
    } catch {
        Write-Warning "Group '$Group' not found in AD. Skipping."
        continue
    }

    foreach ($User in $Users) {
        # Verify user/object exists (could be a user or computer account)
        try {
            $ADObject = Get-ADObject -Filter { SamAccountName -eq $User } -ErrorAction Stop
            if (-not $ADObject) { throw "Not found" }
        } catch {
            Write-Warning "User/object '$User' not found in AD. Skipping."
            $Results.Add([PSCustomObject]@{
                User   = $User
                Group  = $Group
                Status = "FAILED - User not found"
            })
            continue
        }

        # Check if already a member
        $IsMember = Get-ADGroupMember -Identity $Group -Recursive |
                    Where-Object { $_.SamAccountName -eq $User }

        if ($IsMember) {
            Write-Host "  [SKIP]  '$User' is already a member of '$Group'" -ForegroundColor Yellow
            $Results.Add([PSCustomObject]@{
                User   = $User
                Group  = $Group
                Status = "SKIPPED - Already a member"
            })
        } else {
            try {
                Add-ADGroupMember -Identity $Group -Members $User -ErrorAction Stop
                Write-Host "  [OK]    Added '$User' to '$Group'" -ForegroundColor Green
                $Results.Add([PSCustomObject]@{
                    User   = $User
                    Group  = $Group
                    Status = "SUCCESS"
                })
            } catch {
                Write-Warning "Failed to add '$User' to '$Group': $_"
                $Results.Add([PSCustomObject]@{
                    User   = $User
                    Group  = $Group
                    Status = "FAILED - $($_.Exception.Message)"
                })
            }
        }
    }
}

# --- Summary ---
Write-Host "`n===== Summary =====" -ForegroundColor Cyan
$Results | Format-Table -AutoSize

$SuccessCount = ($Results | Where-Object { $_.Status -eq "SUCCESS" }).Count
$SkipCount    = ($Results | Where-Object { $_.Status -like "SKIPPED*" }).Count
$FailCount    = ($Results | Where-Object { $_.Status -like "FAILED*" }).Count

Write-Host "Added:   $SuccessCount" -ForegroundColor Green
Write-Host "Skipped: $SkipCount"    -ForegroundColor Yellow
Write-Host "Failed:  $FailCount"    -ForegroundColor Red
