# Add-LocalUsersToGroups.ps1
# Adds local user accounts to local groups (no Active Directory / domain required)
# Run as Administrator

#Requires -RunAsAdministrator

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
    # Verify group exists locally
    try {
        $LocalGroup = Get-LocalGroup -Name $Group -ErrorAction Stop
    } catch {
        Write-Warning "Group '$Group' not found on this machine. Skipping."
        continue
    }

    foreach ($User in $Users) {
        # Verify user exists locally
        try {
            $LocalUser = Get-LocalUser -Name $User -ErrorAction Stop
        } catch {
            Write-Warning "User '$User' not found on this machine. Skipping."
            $Results.Add([PSCustomObject]@{
                User   = $User
                Group  = $Group
                Status = "FAILED - User not found"
            })
            continue
        }

        # Check if already a member
        $IsMember = Get-LocalGroupMember -Group $Group -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like "*\$User" -or $_.Name -eq $User }

        if ($IsMember) {
            Write-Host "  [SKIP]  '$User' is already a member of '$Group'" -ForegroundColor Yellow
            $Results.Add([PSCustomObject]@{
                User   = $User
                Group  = $Group
                Status = "SKIPPED - Already a member"
            })
        } else {
            try {
                Add-LocalGroupMember -Group $Group -Member $User -ErrorAction Stop
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
