#!/usr/bin/env powershell

# Immediately stop script execution when an error occurs.
$ErrorActionPreference = 'Stop'

# Current directory path
$originalLocation = Get-Location

# Project folder name
$projectFolder = 'app-prod'

# 1 - clone the repository (the remote repository must be up to date)
$accessToken = (Get-Content "$originalLocation\.env" -Raw) -match 'GITHUB_ACCESS_TOKEN=(.+)'; $accessToken = $matches[1].Trim()
$repositoryName = (Get-Content "$originalLocation\.env" -Raw) -match 'GITHUB_REPOSITORY_NAME=(.+)'; $repositoryName = $matches[1].Trim()
git clone "https://$accessToken@github.com/BouiMust/$repositoryName.git" $projectFolder

# 2 - Copy the .env.local.php file
Copy-Item $originalLocation\.env.local.php .\$projectFolder\backend\

# 3 - Install the dependencies
Set-Location .\$projectFolder\backend\
symfony composer install --no-dev --optimize-autoloader

# 4 - install symfony/apache-pack (if production server = apache)
# Must answer 'y' to generate .htaccess file
symfony composer require symfony/apache-pack

# 5 - Update the hosted database structure
# Press 'enter' to confirm the migration
# Need to update/import datas manually, with sql file
symfony console d:m:m

# 6 - Generate jwt keys in config/jwt/
# Need to input passphrase manually
mkdir -p .\config\jwt
openssl genpkey -out .\config\jwt\private.pem -aes256 -algorithm rsa -pkeyopt rsa_keygen_bits:4096
openssl pkey -in .\config\jwt\private.pem -out .\config\jwt\public.pem -pubout

# 7 - Get api url from .env file and modify all urls from js files
Write-Host "Url api replacement..."
Set-Location ..\
$apiUrl = (Get-Content "$originalLocation\.env" -Raw) -match 'API_URL=(.+)'; $apiUrl = $matches[1]
$files = Get-ChildItem -Path ".\public\assets\js" -Recurse -File
foreach ($file in $files) {
    (Get-Content $file.FullName) -replace 'localhost:8000', $apiUrl | Set-Content $file.FullName
}

# 8 - Minify the front-end code
Write-Host "Minifying front-end files..."
Get-ChildItem -Path ".\public\" -Filter "*.html" | ForEach-Object {
    $fileContent = Get-Content $_.FullName -Raw
    $newContent = Optimize-HTML -Content $fileContent
    Set-Content -Path $_.FullName -Value $newContent
}
$files = Get-ChildItem -Path ".\public\assets\css\" -Recurse -File -Filter "*.css"
foreach ($file in $files) {
    node-minify --compressor clean-css --input $file.FullName --output $file.FullName --silence
}
$files = Get-ChildItem -Path ".\public\assets\js\" -Recurse -File -Filter "*.js"
foreach ($file in $files) {
    node-minify --compressor uglify-js --input $file.FullName --output $file.FullName --silence
}

# 9 - Delete var folder (not needed)
Write-Host "Deleting var folder..."
Remove-Item -r ".\backend\var"

# 10 - Check packages vulnerability
Set-Location .\backend\
symfony check:security

Write-Host "Script execution completed ! Application is now ready for production. Copy your app to the remote server, using FTP client."
Set-Location $originalLocation
