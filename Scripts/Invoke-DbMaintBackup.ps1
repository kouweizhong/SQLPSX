function Invoke-DBMaintBackup
{
	#requires -Version 2
	
	<#
		.SYNOPSIS
		Generate a Backup Maintenance
		
		.DESCRIPTION
		Generate a Backup Maintenance
		Version 2.01
		Codeplex-SQLPSX SQL Server Powershell Extensions Team
		www.sqlpsx.codeplex.com
		http://chadwickmiller.spaces.live.com
		http://laertejuniordba.spaces.live.com
		
		.PARAMETER Server
		String Server Name . Accept value from Pipe
		.PARAMETER Databases
		String with Databases. You can choose "All" All Databases, "User" All User Databases, "System" All System Databases
		.PARAMETER UserName
		String with UserName. If not pass, Windows Authentication will be used 
		.PARAMETER Password
		String with Password. 
		.PARAMETER Action
		SMO backup Action . Default Database. Can be "Database","Log","File"
		.PARAMETER Incremental
		Boolean indicate if is differential backup. Default False 
		.PARAMETER CopyOnly
		Boolean indicate if is a CopyOnly Backup. Default False 
		.PARAMETER BackupOn
		String. Path to generate Backup Files. Default to c:\temp, The path is tested if exists.
		The backup file will be generated as Server_Database_Date(yyyyMMddhhmmss).Extension (bak,trn)
		.PARAMETER ReportOn
		String. Path to generate Log File. This log file contains all servers/databases backuped with success and failure.
		If not especified the path , the log will not be generated.
		.PARAMATER RemoveOldBackups
		Int. Indicate the number of days to do a housekeeping of old backups.
		.PARAMATER RemoveOldBackupsReports
		Int. Indicate the number of days to do a housekeeping of old REPORTS backups, generated by ReportON.
		
		.Examples
		get-content ./servers.txt | Invoke-DBMaintBackup -Databases User  -action "Log" -BackupOn C:\Temp -ReportOn c:\Temp -RemoveOldBackups 1 -RemoveOldBackupsReports 1
		Invoke-DBMaintBackup -server R2D2 -Databases System -UserName LoginTeste -Password teste -action "Database" -BackupOn C:\Temp -ReportOn c:\Temp -RemoveOldBackups 1 -RemoveOldBackupsReports 1

	#>




	
	param (
			[Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [string]$server,
			
			[Parameter(position=1,Mandatory = $true )]
			[ValidateSet("All", "User", "System")]
			[string] 	$Databases ,

			[Parameter(position=2,Mandatory = $false )]
			[string] 	$UserName = "" ,
			
			[Parameter(position=3,Mandatory = $false )]
			[string] 	$Password = "" ,
		
			[Parameter(position=4,Mandatory = $False )]
			[ValidateSet("Database","Log","File")]
			[Microsoft.SqlServer.Management.Smo.BackupActionType]  	$Action = "Database" ,
			
			[Parameter(position=5,Mandatory = $False )]
			[switch]  	$incremental = $false ,
			
			[Parameter(position=6,Mandatory = $False )]
			[switch]  	$CopyOnly = $false ,
			
			[Parameter(position=7,Mandatory = $false )] 
			[ValidateScript({Test-Path -path $_})]
			[String] 	$BackupOn = "c:\temp",
			
			[Parameter(position=8,Mandatory = $false )]
			[ValidateScript({Test-Path -path $_})]
			[String] 	$ReportOn = "",
			
			[Parameter(position=9,Mandatory = $false )]
			[ValidateRange(1,365)]
			[System.Int32] 	$RemoveOldBackups = 0,
			
			[Parameter(position=10,Mandatory = $false )]
			[ValidateRange(1,365)]
			[System.Int32]  $RemoveOldBackupsReports = 0
			
			)
   
			process 
			{
				#Set Action Preference
				$ErrorActionPreference = "Continue"
				
				#Starts msg with <enter>
				$Msg = [char]13+[char]10
				
				try {
				
						if ($UserName -ne "" -or $Password -ne "")
							{$server =  Get-SqlServer  -sqlserver $server -username $UserName -password $Password}
							
						switch ($Databases)
						{
							'All' { $dbs = Get-SqlDatabase $server -force | Where-Object {$_.name -ne 'tempdb'}}
							'System' { $dbs = Get-SqlDatabase $server -force | where {$_.IsSystemObject -and $_.name -ne 'tempdb'} }
							'User' { $dbs = Get-SqlDatabase $server  }
						
						}
						
						$extension = ".bak"

						if ($Action -eq "Log") 
							{ $extension = ".Trn" }
							
						if ($incremental)
							{ $extension = "_Diff.bak"}
							
							
						$ServerName = ((( $server -replace '\\','_') -replace '\[','') -replace '\]','')
						
											
						$dbs |	foreach { 
											Invoke-SqlBackup -sqlserver $_.parent -dbname $_.name -action $Action -incremental $incremental -copyOnly $CopyOnly  -filepath (join-path $BackupOn "$($ServerName )$($_.name)$(get-date -format yyyyMMddhhmmss)$extension") -force 
											if ($?)
												{$Msg += "Backup for $server $($_.name) to $($filepath) completed." + [char]13+[char]10}
											else
												{$Msg += "Backup failed for $server $($_.name) Database $($_.name). Error details $error[0]" + [char]13+[char]10}
										} 
					} catch {
						$Msg += "Backup failed for $server $($_.name) Error details $error[0]" + [char]13+[char]10
					}
					

					
					if ($reporton -ne "")
					  	{ $Msg | Out-File (Join-Path $ReportOn "Invoke_DBMaintBackup_$($ServerName)_$(get-date -format yyyyMMddhhmmss).log")  }
						
					if ($RemoveOldBackups -gt 0)
					{
						try
						{
							#Only strings match $servername AND not match .log
							Get-ChildItem $($BackupOn) | Where-Object {$_.name -match "(.*$servername.*)[^\.log]" -and (get-date).subtract($_.LastWriteTime).days -ge $RemoveOldBackups  } |  remove-item  -Force
					
						}catch {
							Write-Error $Error[0]
						}
					}
						
					if ($RemoveOldBackupsReports -gt 0 -and $ReportOn -ne "" )
					{
						try
						{
							#Only strings match $servername AND match .log
							Get-ChildItem $($ReportOn) | Where-Object { $_.name -match "(.*$servername.*)(\.log)" -and (get-date).subtract($_.LastWriteTime).days -ge $RemoveOldBackupsReports } | remove-item -force 
						
						}catch {
							Write-Error $Error[0]
						}
					}
			}
		
}