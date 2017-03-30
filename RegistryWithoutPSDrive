  # here is an example of using the same method of reg load, but without the New-PSDrive cmdlet.
  # Here we can load all unloaded user hives and do whatever we want in the location below (comments)
  
  $PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
	
	Write-Verbose -Message 'Gathering Profile List and loading their registry hives'
	# Get Username, SID, and location of ntuser.dat for all users

  $ProfileList = @()
  $ProfileList = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object { $_.PSChildName -match $PatternSID } |
    Select  @{ name = "SID"; expression = { $_.PSChildName } },
			      @{ name = "UserHive"; expression = { "$($_.ProfileImagePath)\ntuser.dat" } },
			      @{ name = "Username"; expression = { $_.ProfileImagePath -replace '^(.*[\\\/])', '' } }
		
  # Get all user SIDs found in HKEY_USERS (ntuder.dat files that are loaded)
  $LoadedHives = Get-ChildItem Registry::HKEY_USERS | ? { $_.PSChildname -match $PatternSID } | Select @{ name = "SID"; expression = { $_.PSChildName } }
        
  $SIDObject = @()
    
  foreach ($item in $LoadedHives)
  {
      $props = @{
          SID = $item.SID
      }

      $TempSIDObject = New-Object -TypeName PSCustomObject -Property $props
      $SIDObject += $TempSIDObject
  }

  # We need to use ($ProfileList | Measure-Object).count instead of just ($ProfileList).count because in PS V2
  # if the count is less than 2 it doesn't work. :)
  for ($p = 0; $p -lt ($ProfileList | Measure-Object).count; $p++)
  {
      for ($l = 0; $l -lt ($SIDObject | Measure-Object).count; $l++)
      {
          if (($ProfileList[$p].SID) -ne ($SIDObject[$l].SID))
          {
              $UnloadedHives += $ProfileList[$p].SID
              Write-Verbose -Message "Loading Registry hives for $($ProfileList[$p].SID)"
              reg load "HKU\$($ProfileList[$p].SID)" "$($ProfileList[$p].UserHive)"

              Write-Verbose -Message 'Attempting to remove registry keys for each profile'
              #####################################################################
              # This is where you can read/modify a users portion of the registry 
          }
      }
  }

  Write-Verbose 'Unloading Registry hives for all users'
  # Unload ntuser.dat        
  ### Garbage collection and closing of ntuser.dat ###
  [gc]::Collect()
  reg unload "HKU\$($ProfileList[$p].SID)"
