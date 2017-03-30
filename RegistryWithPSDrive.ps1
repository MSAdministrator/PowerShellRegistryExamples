# We can load a registry hive using the old school "reg load" and "reg unload" commands, but this does not work well with older
# operating systems.  Especially with systems that are running a default install of Windows 7

$ntuserlocation = 'C:\users\TempUser\ntuser.dat'

reg load 'HKLM\TempUser' $ntuserlocation
 
cd hklm:\TempUser
 
gci
 
New-PSDrive -Name HKMyUser -PSProvider Registry -Root HKLM\TempUser
 
cd HKMyUser:\
 
gci
 
cd c:
 
Remove-PSDrive HKMyUser
 
reg unload hklm\TempUser
