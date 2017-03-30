# These functions are an example of what you can do with the WIN_API
# I have a complete PowerShell Module that basically wraps the entire 
# "advapi32.dll" for registry access into a PS Module.  It is still a work 
# in progress, but I have around 15 PS functions and tests written for all of them
# 
# To sum it up, basically I've recreated what the reg load/unload commands do by using the 
# native Windows methods.  I have not released this yet, but when I do this could also be another 
# larger post.

# TO run the Mount-Registry function you should do the following:
# Mount-RegistryHive -Hive C:\Users\first.last\NTUSER.DAT 
# It should return something like
# e9f537de-3246-4d61-9622-046fdda0e642

# To run the Dismount-Registry function you should do the following:
# Dismount-Registry -MountKey e9f537de-3246-4d61-9622-046fdda0e642 -KeyType HKCU





function Set-TokenPrivilege
{
    [CmdletBinding(
        SupportsShouldProcess=$true
        )]
    [Alias()]
    [OutputType()]
    param(

      # The privilege to adjust. This set is taken from
      # http://msdn.microsoft.com/library/bb530716

        [ValidateSet(
            "SeAssignPrimaryTokenPrivilege",
            "SeAuditPrivilege",
            "SeBackupPrivilege",
            "SeChangeNotifyPrivilege",
            "SeCreateGlobalPrivilege",
            "SeCreatePagefilePrivilege",
            "SeCreatePermanentPrivilege",
            "SeCreateSymbolicLinkPrivilege",
            "SeCreateTokenPrivilege",
            "SeDebugPrivilege",
            "SeEnableDelegationPrivilege",
            "SeImpersonatePrivilege",
            "SeIncreaseBasePriorityPrivilege",
            "SeIncreaseQuotaPrivilege",
            "SeIncreaseWorkingSetPrivilege",
            "SeLoadDriverPrivilege",
            "SeLockMemoryPrivilege",
            "SeMachineAccountPrivilege",
            "SeManageVolumePrivilege",
            "SeProfileSingleProcessPrivilege",
            "SeRelabelPrivilege",
            "SeRemoteShutdownPrivilege",
            "SeRestorePrivilege",
            "SeSecurityPrivilege",
            "SeShutdownPrivilege",
            "SeSyncAgentPrivilege",
            "SeSystemEnvironmentPrivilege",
            "SeSystemProfilePrivilege",
            "SeSystemtimePrivilege",
            "SeTakeOwnershipPrivilege",
            "SeTcbPrivilege",
            "SeTimeZonePrivilege",
            "SeTrustedCredManAccessPrivilege",
            "SeUndockPrivilege",
            "SeUnsolicitedInputPrivilege"
        )]
        $Privilege,

      # The process on which to adjust the privilege. Defaults to the current process.
        $ProcessId = $pid,

      # Switch to disable the privilege, rather than enable it.
        [Switch]
        $Disable
    )

  # Taken from P/Invoke.NET with minor adjustments.
    $Definition = @'
    using System;
    using System.Runtime.InteropServices;
    public class AdjPriv
    {
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
        ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
        [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
        internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
        [DllImport("advapi32.dll", SetLastError = true)]
        internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        internal struct TokPriv1Luid
        {
            public int Count;
            public long Luid;
            public int Attr;
        }
        internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
        internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
        internal const int TOKEN_QUERY = 0x00000008;
        internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
        public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
        {
            bool retVal;
            TokPriv1Luid tp;
            IntPtr hproc = new IntPtr(processHandle);
            IntPtr htok = IntPtr.Zero;
            retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
            tp.Count = 1;
            tp.Luid = 0;
            if(disable)
            {
                tp.Attr = SE_PRIVILEGE_DISABLED;
            }
            else
            {
                tp.Attr = SE_PRIVILEGE_ENABLED;
            }
            retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
            retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            return retVal;
        }
    }
'@

    If ($PSCmdlet.ShouldProcess(“Get process handle successfully“)) 
    {
        $processHandle = ( Get-Process -id $ProcessId ).Handle
    }

    If ($PSCmdlet.ShouldProcess(“Added type definition successfully“)) 
    {
        $Type = Add-Type -TypeDefinition $Definition -PassThru
    }
    If ($PSCmdlet.ShouldProcess(“Setting privelege on process successfully“)) 
    {
        $Type[0]::EnablePrivilege( $ProcessHandle, $Privilege, $Disable )
    }
}


function Add-RegLoadType
{
    [CmdletBinding()]
    [Alias()]
    [OutputType()]
    Param()

    Write-Verbose -Message 'Adding RegLoad definition'
    
    try
    {
        $Definition = @"
[DllImport("advapi32.dll", SetLastError=true)]
public static extern long RegLoadKey(int hKey, String lpSubKey, String lpFile);
"@

        $Reg = Add-Type -MemberDefinition $Definition -Name "RegLoad" -Namespace "Win32Functions" -PassThru
    }
    catch
    {
        Write-LogEntry -type Error -message 'Error attempting to add RegLoad type' -thisError $($Error[0] | Format-List -Force)
    }
    
    return $Reg
}

function Add-RegUnLoadType
{
    [CmdletBinding()]
    [Alias()]
    [OutputType()]
    Param()

    Write-Verbose -Message 'Adding RegUnLoad definition'
    
    try
    {
        $Definition = @"
[DllImport("advapi32.dll", SetLastError=true)]
public static extern int RegUnLoadKey(int hKey,string lpSubKey);
"@

        $Reg = Add-Type -MemberDefinition $Definition -Name "RegUnload" -Namespace "Win32Functions" -PassThru
    }
    catch
    {
        Write-LogEntry -type Error -message 'Error attempting to add RegLoad type' -thisError $($Error[0] | Format-List -Force)
    }
    
    return $Reg
}


function Mount-RegistryHive
{
    [CmdletBinding()]
    param(
        
        # Location of NTUSER.dat file
        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True,
            Position          = 0
        )]
        [System.IO.FileInfo]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            { $_.Exists }
           )]
        $NTUSER,
        
        #Registry Key type can be HKLM or HKU
        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True,
            Position          = 1
        )] 
        [ValidateSet(
            'HKLM',
            'HKU'
        )]
        [string]$KeyType
    )

    Write-Verbose -Message 'Creating new GUID for mountpoint'

    $mountKey = New-Guid

    Try
    {
        $TokenPrivilege = Set-TokenPrivilege -Privilege "SeBackupPrivilege"
        $TokenPrivilege = Set-TokenPrivilege -Privilege "SeRestorePrivilege"

        $HKLM = 0x80000002
        $HKU  = 0x80000003

        $Reg = Add-RegLoadType

        switch ($PSBoundParameters.ContainsKey($KeyType))
        {
            'HKLM' { $Result = $Reg::RegLoadKey( $HKLM, $mountKey, $NTUSER ) }
            'HKU'  { $Result = $Reg::RegLoadKey( $HKU, $mountKey, $NTUSER )  }
        }

        $props = @{
            KeyType = $KeyType
            MountKey = $mountKey
        }

        $returnObject = New-Object -TypeName PSCustomObject -Property $props

        return $returnObject
    }
    Catch
    {
        Write-LogEntry -type Error -message 'Error attempting to mount registry' -thisError $($Error[0] | Format-List -Force)
    }
}

function Dismount-RegistryHive
{
    [CmdletBinding()]
    param(
        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True,
            Position          = 0
        )]
        [System.Guid]
        [ValidateNotNullOrEmpty()]
        $MountKey,

        #Registry Key type can be HKLM or HKU
        [Parameter(
            Mandatory         = $True,
            ValueFromPipeline = $True,
            Position          = 1
        )] 
        [ValidateSet(
            'HKLM',
            'HKU'
        )]
        [string]$KeyType
    )

    Try
    {
        Write-Verbose -Message 'Setting priveleges on registry'
        $TokenPrivilege = Set-TokenPrivilege -Privilege "SeBackupPrivilege"
        $TokenPrivilege = Set-TokenPrivilege -Privilege "SeRestorePrivilege"

        $HKLM = 0x80000002
        $HKU  = 0x80000003

        $Reg = Add-RegUnLoadType

        switch ($PSBoundParameters.ContainsKey($KeyType))
        {
            'HKLM' { $Result = $Reg::RegUnLoadKey( $HKLM, $MountKey) }
            'HKU'  { $Result = $Reg::RegUnLoadKey( $HKU, $MountKey ) }
        }

        return $True
    }
    Catch
    {
        Write-LogEntry -type Error -message 'Error attempting to unmount registry' -thisError $($Error[0] | Format-List -Force)
    }

    $global:mountedHive = $null
}
