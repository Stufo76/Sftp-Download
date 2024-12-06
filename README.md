# SFTP Download Script

## Description

This PowerShell script (`sftp_download.ps1`) is designed to automate file downloads from an SFTP server, handle log rotation, and create backup copies. It is ideal for workflows requiring regular and secure management of remote files.

### Key Features

- Automated connection to an SFTP server using secure credentials.
- Download files from a specified remote directory.
- Automatic backup of downloaded files.
- Daily log rotation and compression.
- Error handling throughout the download and backup process.

## Requirements

- **PowerShell**: The script is written and tested using PowerShell 5.1.
- **Posh-SSH Module**: Ensure the [Posh-SSH](https://github.com/darkoperator/Posh-SSH) module is installed, which is used to handle the SFTP connection.
- **Encrypted Credentials**: The script requires credentials to be stored in encrypted XML files using `Export-CliXml`.

### Installing Posh-SSH Module

```powershell
Install-Module -Name Posh-SSH -Scope CurrentUser -Force
```

## Configuration

Before running the script, make sure to configure the following parameters:

- **SFTP Configuration**: Set the host, port, and remote path for file downloads.
- **Network Drive Configuration**: Configure the local network drive for backing up the downloaded files.
- **Credentials**: Save the required credentials in encrypted XML files for SFTP access and network drive.

### Creating Credential Files

Run the following commands to create the credential files:

```powershell
$username = "your_username"
$password = ConvertTo-SecureString "your_password" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($username, $password)

# Save the SFTP credentials
$credential | Export-CliXml -Path "C:\script\sftp_download\sftp_credentials.xml"

# Save the network drive credentials
$credential | Export-CliXml -Path "C:\script\sftp_download\netdrive_credentials.xml"
```

## Usage

1. **Clone the Repository**

   Clone the repository from your GitHub account:

   ```sh
   git clone https://github.com/Stufo76/Sftp-Download.git
   ```

2. **Run the Script**

   To run the script, open PowerShell as an administrator and execute the following command:

   ```powershell
   .\sftp_download.ps1
   ```

## License

This project is licensed under the GPL-3.0 License. For more details, refer to the [LICENSE](https://www.gnu.org/licenses/gpl-3.0.html).

## Author

- **Diego Pastore**  
  - GitHub: [Stufo76](https://github.com/Stufo76)
  - Email: stufo76@gmail.com

## Notes

- Ensure the `Posh-SSH` module is installed and loaded correctly.
- The credential files are encrypted and can only be used by the user who created them.
- It is recommended to run this script in a secure environment, as operations involving remote files and credentials are sensitive.

---

If you have suggestions, issues, or questions, feel free to open an Issue or make a Pull Request. Thank you for using this script!
