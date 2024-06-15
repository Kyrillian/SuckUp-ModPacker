# Load necessary assemblies for Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Function to list all character folders from both def\Characters and Mods
function Get-CharacterFolders {
    $characterPaths = @(
        "$env:userprofile\appdata\locallow\Proxima\Custom User Data\def\Characters",
        "$env:userprofile\appdata\locallow\Proxima\Mods"
    )
    $allFolders = @()
    foreach ($path in $characterPaths) {
        if (Test-Path $path) {
            $folders = Get-ChildItem -Path $path -Directory | Sort-Object Name
            $allFolders += $folders
        }
    }
    if ($allFolders.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No character folders found.")
        return $null
    }
    return $allFolders
}

# Function to list all level files
function Get-LevelFiles {
    $levelPath = "$env:userprofile\appdata\locallow\Proxima\Custom User Data\def\Levels"
    if (Test-Path $levelPath) {
        $files = Get-ChildItem -Path $levelPath -File -Filter *.xml | Sort-Object Name
        return $files
    } else {
        [System.Windows.Forms.MessageBox]::Show("Level path not found.")
        return $null
    }
}

# Function to create the .zip archive for character
function Create-CharacterModPack {
    param (
        [string]$characterName,
        [string]$characterFolder,
        [string]$outputDirectory
    )

    $zipPath = "$outputDirectory\$characterName.zip"
    $tempFolder = "$outputDirectory\Temp"

    # Create the required directory structure
    $modPackStructure = "$tempFolder\def\Characters\$characterName"
    New-Item -ItemType Directory -Force -Path $modPackStructure

    # Copy contents to the temp folder
    Copy-Item -Path "$characterFolder\*" -Destination $modPackStructure -Recurse

    # Create the .zip archive
    Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipPath

    # Clean up temporary files
    Remove-Item -Path $tempFolder -Recurse -Force

    [System.Windows.Forms.MessageBox]::Show("Mod pack created successfully at: $zipPath")
}

# Function to create the .zip archive for level
function Create-LevelModPack {
    param (
        [string]$levelName,
        [string]$levelFile,
        [string]$outputDirectory
    )

    $levelPath = "$env:userprofile\appdata\locallow\Proxima\Custom User Data\def\Levels"
    $characterPaths = @(
        "$env:userprofile\appdata\locallow\Proxima\Custom User Data\def\Characters",
        "$env:userprofile\appdata\locallow\Proxima\Mods"
    )

    $zipPath = "$outputDirectory\$levelName.zip"
    $tempFolder = "$outputDirectory\Temp"

    # Create the required directory structure for level
    $modPackStructureLevel = "$tempFolder\def\Levels"
    New-Item -ItemType Directory -Force -Path $modPackStructureLevel

    # Copy level file to the temp folder
    Copy-Item -Path "$levelPath\$levelFile" -Destination "$modPackStructureLevel\$($levelFile)"

    # Read the XML file to find referenced characters
    [xml]$xml = Get-Content "$levelPath\$levelFile"
    
    # Extract all characters from XML
    $characters = @()
    if ($xml.LevelData.Guard.Character -ne $null) {
        $characters += $xml.LevelData.Guard.Character
    }
    if ($xml.LevelData.Houses.House -ne $null) {
        foreach ($house in $xml.LevelData.Houses.House) {
            if ($house.Character -ne $null) {
                $characters += $house.Character
            }
        }
    }
    $characters = $characters | Where-Object { $_ -ne "" }

    # Create the required directory structure for each referenced character
    $allCharactersFound = $true

    foreach ($character in $characters) {
        if (-not [string]::IsNullOrWhiteSpace($character)) {
            $characterFolder = $null
            foreach ($path in $characterPaths) {
                $characterFolder = Get-ChildItem -Path $path -Directory | Where-Object { $_.Name -eq $character }
                if ($characterFolder) { break }
            }
            if ($characterFolder) {
                $modPackStructureCharacter = "$tempFolder\def\Characters\$character"
                New-Item -ItemType Directory -Force -Path $modPackStructureCharacter

                # Copy character contents to the temp folder
                Copy-Item -Path "$($characterFolder.FullName)\*" -Destination $modPackStructureCharacter -Recurse
            } else {
                $result = [System.Windows.Forms.MessageBox]::Show("Character '$character' not found. Is this an official Suck Up! character?", "Character Not Found", [System.Windows.Forms.MessageBoxButtons]::YesNo)
                if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                    # Continue without packing this character
                    continue
                } else {
                    [System.Windows.Forms.MessageBox]::Show("Error: Character '$character' not found.")
                    $allCharactersFound = $false
                    break
                }
            }
        }
    }

    if ($allCharactersFound) {
        # Create the .zip archive
        Compress-Archive -Path "$tempFolder\*" -DestinationPath $zipPath -Force

        # Clean up temporary files
        Remove-Item -Path $tempFolder -Recurse -Force

        [System.Windows.Forms.MessageBox]::Show("Mod pack created successfully at: $zipPath")
    } else {
        # Clean up temporary files
        Remove-Item -Path $tempFolder -Recurse -Force
        [System.Windows.Forms.MessageBox]::Show("Mod pack creation failed due to missing characters.")
    }
}

# Initialize the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Kyrillians Supercool Suck Up! Mod Packer"
$form.Size = New-Object System.Drawing.Size(600,400)
$form.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Location).Path + "\appicon.ico")

# Add DataGridView for characters
$characterGridView = New-Object System.Windows.Forms.DataGridView
$characterGridView.Location = New-Object System.Drawing.Point(10,60)
$characterGridView.Size = New-Object System.Drawing.Size(260,250)
$characterGridView.ReadOnly = $true
$characterGridView.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$characterGridView.Columns.Add("Index", "Index")
$characterGridView.Columns.Add("CharacterName", "Character Name")

# Add DataGridView for levels
$levelGridView = New-Object System.Windows.Forms.DataGridView
$levelGridView.Location = New-Object System.Drawing.Point(280,60)
$levelGridView.Size = New-Object System.Drawing.Size(260,250)
$levelGridView.ReadOnly = $true
$levelGridView.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$levelGridView.Columns.Add("Index", "Index")
$levelGridView.Columns.Add("LevelName", "Level Name")

# Add controls to the form
$label = New-Object System.Windows.Forms.Label
$label.Location = New-Object System.Drawing.Point(10,20)
$label.Size = New-Object System.Drawing.Size(380,20)
$label.Text = "Choose an option to create a modpack:"

$buttonCharacter = New-Object System.Windows.Forms.Button
$buttonCharacter.Location = New-Object System.Drawing.Point(10,320)
$buttonCharacter.Size = New-Object System.Drawing.Size(260,40)
$buttonCharacter.Text = "Create a modpack for selected character"
$buttonCharacter.Add_Click({
    if ($characterGridView.SelectedRows.Count -eq 1) {
        $selectedRow = $characterGridView.SelectedRows[0]
        $characterName = $selectedRow.Cells["CharacterName"].Value
        $characterFolders = Get-CharacterFolders
        $characterFolder = $characterFolders | Where-Object { $_.Name -eq $characterName }
        if ($characterFolder) {
            $outputDirectory = Get-Location
            Create-CharacterModPack -characterName $characterName -characterFolder $characterFolder.FullName -outputDirectory $outputDirectory
        } else {
            [System.Windows.Forms.MessageBox]::Show("Invalid selection.")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a character.")
    }
})

$buttonLevel = New-Object System.Windows.Forms.Button
$buttonLevel.Location = New-Object System.Drawing.Point(280,320)
$buttonLevel.Size = New-Object System.Drawing.Size(260,40)
$buttonLevel.Text = "Create a modpack for selected level"
$buttonLevel.Add_Click({
    if ($levelGridView.SelectedRows.Count -eq 1) {
        $selectedRow = $levelGridView.SelectedRows[0]
        $levelName = $selectedRow.Cells["LevelName"].Value
        $levelFiles = Get-LevelFiles
        $levelFile = $levelFiles | Where-Object { $_.Name -eq "$levelName.xml" }
        if ($levelFile) {
            $outputDirectory = Get-Location
            Create-LevelModPack -levelName $levelName -levelFile $levelFile -outputDirectory $outputDirectory
        } else {
            [System.Windows.Forms.MessageBox]::Show("Invalid selection.")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please select a level.")
    }
})

$buttonExit = New-Object System.Windows.Forms.Button
$buttonExit.Location = New-Object System.Drawing.Point(10,370)
$buttonExit.Size = New-Object System.Drawing.Size(530,40)
$buttonExit.Text = "Exit"
$buttonExit.Add_Click({
    $form.Close()
})

# Populate DataGridView for characters
$characterFolders = Get-CharacterFolders
if ($characterFolders) {
    $index = 1
    foreach ($folder in $characterFolders) {
        $characterGridView.Rows.Add($index, $folder.Name)
        $index++
    }
}

# Populate DataGridView for levels
$levelFiles = Get-LevelFiles
if ($levelFiles) {
    $index = 1
    foreach ($file in $levelFiles) {
        $levelGridView.Rows.Add($index, [System.IO.Path]::GetFileNameWithoutExtension($file.Name))
        $index++
    }
}

# Add controls to the form
$form.Controls.Add($label)
$form.Controls.Add($characterGridView)
$form.Controls.Add($levelGridView)
$form.Controls.Add($buttonCharacter)
$form.Controls.Add($buttonLevel)
$form.Controls.Add($buttonExit)

# Show the form
$form.ShowDialog()
