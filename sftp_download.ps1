# Script Name: sftp_download.ps1
# Script for SFTP file download, log rotation, and cleanup.

<#
    Author: Diego Pastore (https://github.com/Stufo76, stufo76@gmail.com)
    Description:
    This script downloads files from an SFTP server, rotates logs,
    and copies files to a backup directory. The log file is named `sftp_download.log` for the current day.
    Older logs are rotated with the format `YYYY-MM-DD_sftp_download.log`.

    License: GPL-3.0
    This script is licensed under the GNU General Public License v3.0.
    You are free to use, modify, and distribute it under the terms of the GPL-3.0 license.

#>

# -------------------- SECTION: PARAMETERS --------------------

# SFTP Configuration - Parameters to connect to the SFTP server
$SftpHost = "your_sftp_server.com" # SFTP server address
$SftpPort = 22 # SFTP server port
$RemotePath = "/path/to/remote" # Path on the SFTP server from where files will be downloaded

# Network Drive Configuration - Parameters for mounting a network drive
$LocalDriveLetter = "Z" # Drive letter to be used for network mapping
$NetworkPath = "\\your.network.path\share" # Path to network share
$BackupSubFolder = "backup" # Sub-folder for backups

# Log Configuration - Paths and retention settings for log files
$LogDirectory = "C:\script\sftp_download\log\" # Directory where logs are stored
$BaseLogFileName = "sftp_download.log" # Base name for the log file
$RetentionDays = 30 # Number of days after which old logs will be deleted

# Temporary Directory Configuration - Directory used for temporary storage during downloads
$TempDirectory = "C:\script\sftp_download\temp" # Temporary directory used during download process

# Behavior Parameters - Set to true if files should be deleted from SFTP after successful download
$DeleteAfterDownload = $true # Delete remote file from SFTP server after successful download

# Credential Paths - Paths to encrypted credential files for SFTP and network drive
$SftpCredentialPath = "C:\script\sftp_download\sftp_credentials.xml" # Path to SFTP credentials file
$NetDriveCredentialPath = "C:\script\sftp_download\netdrive_credentials.xml" # Path to network drive credentials file

# Initialize execution status - Tracks the overall success of the script
$ExecutionStatus = $true # Used to track if the script has run without errors

# -------------------- SECTION: FUNCTIONS --------------------

# Log function - Writes messages to the log file
function Write-Log {
    param (
        [string]$Message, # The message to be logged
        [switch]$IsError, # Set this switch to indicate an error message
        [switch]$IsWarning, # Set this switch to indicate a warning message
        [switch]$IsSeparator, # Set this switch to add a thin separator line to the log
        [switch]$IsSeparatorThick # Set this switch to add a thick separator line to the log
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if ($IsSeparator) {
        $LogMessage = "--------------------------------------------------------------------------------"
    }
    elseif ($IsSeparatorThick) {
        $LogMessage = "================================================================================"
    }
    else {
        $LogMessage = "$Timestamp - $Message"
    }

    # Write log message to the current log file
    Add-Content -Path $CurrentLogFilePath -Value $LogMessage

    # Handle execution status for errors or warnings
    if ($IsError) {
        # Mark execution as failed if an error is logged
        $ExecutionStatus = $false
    }
}

# Rotate logs - Rotates the current log if it is from a previous day and deletes old logs
function Rotate-Logs {
    param (
        [string]$LogDirectory, # Directory where logs are stored
        [string]$BaseLogFileName, # Base name of the log file
        [int]$RetentionDays # Number of days to retain old logs
    )
    try {
        # Define paths for the current log file
        $CurrentLogPath = Join-Path $LogDirectory $BaseLogFileName

        # Check if the current log exists
        if (Test-Path $CurrentLogPath) {
            $LogDate = (Get-Item $CurrentLogPath).LastWriteTime.Date
            $Today = (Get-Date).Date

            # Rotate log if it is not from today
            if ($LogDate -lt $Today) {
                $NewLogName = "$($LogDate.ToString('yyyy-MM-dd'))_$BaseLogFileName"
                $NewLogPath = Join-Path $LogDirectory $NewLogName

                # Rename the old log file and compress it
                Rename-Item -Path $CurrentLogPath -NewName $NewLogPath -Force
                Compress-Archive -Path $NewLogPath -DestinationPath "$NewLogPath.zip" -Force
                Remove-Item -Path $NewLogPath -Force
                Write-Log "Rotated and compressed log file: $NewLogName"
            }
        }

        # Delete logs older than the retention period
        $OldLogs = Get-ChildItem -Path $LogDirectory -Filter "*.zip" | Where-Object {
            $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays)
        }

        foreach ($Log in $OldLogs) {
            Remove-Item -Path $Log.FullName -Force
            Write-Log "Deleted old compressed log file: $($Log.FullName)"
        }
    } catch {
        Write-Log "Error rotating logs: $($_.Exception.Message)" -IsError
    }
}

# Mount network drive using net use - Maps a network drive with the provided credentials
function Mount-NetworkDrive {
    param (
        [string]$DriveLetter, # Drive letter to use for the network mapping
        [string]$NetworkPath, # Path to the network resource
        [pscredential]$Credential # Credential to use for network mapping
    )
    try {
        $UserName = $Credential.UserName
        $Password = $Credential.GetNetworkCredential().Password

        Write-Log "Attempting to map drive letter ${DriveLetter}: to $NetworkPath using net use"

        # Command to mount the network drive
        cmd.exe /c "net use ${DriveLetter}: `"$NetworkPath`" $Password /user:$UserName /persistent:no" > $null

        # Verify if the network drive is accessible
        if (Test-Path "${DriveLetter}:\") {
            Write-Log "Mapped network drive ${DriveLetter}: to $NetworkPath"
        } else {
            Write-Log "Error: Drive letter ${DriveLetter}: is not accessible after mapping with net use" -IsError
            throw "Drive mapping failed"
        }
    } catch {
        Write-Log "Error mapping network drive ${DriveLetter}: with net use: $($_.Exception.Message)" -IsError
        throw
    }
}

# Unmount network drive using net use - Unmounts a mapped network drive
function Unmount-NetworkDrive {
    param (
        [string]$DriveLetter # Drive letter to unmount
    )
    try {
        Write-Log "Attempting to unmount network drive ${DriveLetter}:"
        cmd.exe /c "net use ${DriveLetter}: /delete /yes" > $null
        Write-Log "Network drive ${DriveLetter}: unmounted successfully"
    } catch {
        Write-Log "Error unmounting network drive ${DriveLetter}: $($_.Exception.Message)" -IsError
    }
}

# Load encrypted credentials - Loads credentials from an encrypted XML file
function Load-Credential {
    param (
        [string]$FilePath # Path to the encrypted credential file
    )
    try {
        if (Test-Path $FilePath) {
            # Import credentials from the XML file
            return Import-CliXml -Path $FilePath
        } else {
            throw "Credential file not found: $FilePath"
        }
    } catch {
        Write-Log "Error loading credential from ${FilePath}: $($_.Exception.Message)" -IsError
        throw
    }
}

# Download files from SFTP and handle backup - Downloads files, processes them, and manages backup and deletion
function Download-Files {
    param (
        [array]$RemoteFiles, # Array of remote files to be downloaded
        [string]$TempDirectory, # Temporary directory used during download process
        [string]$BackupPath, # Backup directory path
        [string]$RemotePath, # Path on the SFTP server
        [bool]$DeleteAfterDownload, # Delete remote file after successful download
        [object]$SftpSession, # SFTP session object
        [string]$LocalDriveLetter # Local drive letter used for mapping
    )
    foreach ($File in $RemoteFiles) {
        if ($File.IsDirectory -eq $false) {
            # Add a separator for each file processing
            Write-Log -IsSeparator

            $FileProcessedSuccessfully = $true
            $FileName = $File.Name
            $RemoteFilePath = "$RemotePath/$FileName"
            $FinalLocalFilePath = Join-Path "${LocalDriveLetter}:" $FileName
            $BackupFilePath = Join-Path $BackupPath $FileName

            Write-Log "Processing file: $FileName"

            # Check if the file already exists in the destination
            if (Test-Path $FinalLocalFilePath) {
                Write-Log "Warning: File already exists in destination: $FinalLocalFilePath - Skipping download" -IsWarning
                $FileProcessedSuccessfully = $false
            } else {
                try {
                    # Download the file to temporary directory
                    Get-SFTPItem -SessionId $SftpSession.SessionId -Path $RemoteFilePath -Destination $TempDirectory
                    Write-Log "Downloaded file: ${RemoteFilePath} to ${TempDirectory}"

                    # Move file to final destination
                    Move-Item -Path (Join-Path $TempDirectory $FileName) -Destination $FinalLocalFilePath -Force
                    Write-Log "Moved file to final destination: ${FinalLocalFilePath}"
                } catch {
                    Write-Log "Error during download or move operation for file: ${FileName} - $($_.Exception.Message)" -IsError
                    $FileProcessedSuccessfully = $false
                }
            }

            # Copy to backup directory
            if ($FileProcessedSuccessfully -eq $true) {
                if (Test-Path $BackupFilePath) {
                    Write-Log "Warning: File already exists in backup: ${BackupFilePath} - Skipping backup copy" -IsWarning
                    $FileProcessedSuccessfully = $false
                } else {
                    try {
                        # Copy file to backup location
                        Copy-Item -Path $FinalLocalFilePath -Destination $BackupFilePath -Force
                        Write-Log "Copied file to backup: ${BackupFilePath}"
                    } catch {
                        Write-Log "Error during backup copy operation for file: ${FileName} - $($_.Exception.Message)" -IsError
                        $FileProcessedSuccessfully = $false
                    }
                }
            }

            # Delete remote file if everything was successful
            if ($DeleteAfterDownload -eq $true) {
                if ($FileProcessedSuccessfully -eq $true) {
                    try {
                        Remove-SFTPItem -SessionId $SftpSession.SessionId -Path $RemoteFilePath
                        Write-Log "Deleted remote file: ${RemoteFilePath}"
                    } catch {
                        Write-Log "Error deleting remote file ${RemoteFilePath} - $($_.Exception.Message)" -IsError
                    }
                } else {
                    Write-Log "Skipping deletion of remote file: ${RemoteFilePath} due to issues during processing" -IsWarning
                }
            } else {
                Write-Log "Deletion of remote file is disabled by configuration: ${RemoteFilePath}" -IsWarning
            }

        }
    }
}

# Load required PowerShell modules
function Load-Modules {
    try {
        Import-Module Posh-SSH -ErrorAction Stop
        Write-Log "Posh-SSH module loaded successfully"
    } catch {
        Write-Log "Error: Failed to load Posh-SSH module - $($_.Exception.Message)" -IsError
        throw
    }
}

# -------------------- SECTION: EXECUTION --------------------

# Define today's log file path
$CurrentLogFilePath = Join-Path $LogDirectory $BaseLogFileName

# Load required PowerShell modules
Load-Modules

# Rotate old logs
Rotate-Logs -LogDirectory $LogDirectory -BaseLogFileName $BaseLogFileName -RetentionDays $RetentionDays

# Ensure the current log file exists
if (-not (Test-Path $CurrentLogFilePath)) {
    # Create a new log file if it doesn't exist
    New-Item -Path $CurrentLogFilePath -ItemType File | Out-Null
    Write-Log "Created new log file: $CurrentLogFilePath"
}

# Start logging
Write-Log "Starting SFTP download script"

try {
    # Check if log directory exists
    Check-Path -Path $LogDirectory -PathType "Log Directory"

    # Mount network drive before checking its accessibility
    $NetDriveCredential = Load-Credential -FilePath $NetDriveCredentialPath
    Mount-NetworkDrive -DriveLetter $LocalDriveLetter -NetworkPath $NetworkPath -Credential $NetDriveCredential

    # Check if network drive exists after mounting
    Check-Path -Path "${LocalDriveLetter}:\" -PathType "Network Drive"

    # Check if temporary directory exists
    Check-Path -Path $TempDirectory -PathType "Temporary Directory"

    # Load SFTP credentials
    $SftpCredential = Load-Credential -FilePath $SftpCredentialPath

    # Create SFTP session
    $SftpSession = New-SFTPSession -ComputerName $SftpHost -Port $SftpPort -Credential $SftpCredential -AcceptKey
    Write-Log "Connected to SFTP server: $SftpHost"

    # Retrieve file list from SFTP server
    $RemoteFiles = Get-SFTPChildItem -SessionId $SftpSession.SessionId -Path $RemotePath
    Write-Log "Retrieved file list from remote directory: $RemotePath"

    # Check if the file list is empty
    if ($RemoteFiles.Count -eq 0) {
        Write-Log "No files found in the remote directory: $RemotePath"
    } else {
        Write-Log "Number of files found: $($RemoteFiles.Count)"
    }

    # Define backup directory path
    $BackupPath = Join-Path "${LocalDriveLetter}:\" $BackupSubFolder
    Check-Path -Path $BackupPath -PathType "Backup Directory"

    # Download files from SFTP
    Download-Files -RemoteFiles $RemoteFiles -TempDirectory $TempDirectory -BackupPath $BackupPath -RemotePath $RemotePath -DeleteAfterDownload $DeleteAfterDownload -SftpSession $SftpSession -LocalDriveLetter $LocalDriveLetter

} catch {
    Write-Log "Error: $($_.Exception.Message)" -IsError
} finally {
    # Add a separator to the log after processing the last file
    if ($RemoteFiles.Count -ne 0) {
        Write-Log -IsSeparator
    }
    # Unmount network drive
    Unmount-NetworkDrive -DriveLetter $LocalDriveLetter
    Write-Log "SFTP download script completed"

    # Add a separator to the log for clarity
    Write-Log -IsSeparatorThick

    # Check the final execution status and exit with the appropriate code
    if ($ExecutionStatus -eq $false) {
        Write-Log "Script encountered errors during execution. Exiting with error code 1."
        exit 1
    } else {
        Write-Log "Script completed successfully. Exiting with code 0."
        exit 0
    }
}
