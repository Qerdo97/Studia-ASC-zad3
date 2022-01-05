#Ustawiamy domyślne formaty kodowania do UTF8 aby poprawnie wyświetlać polskie znaki diakrytyczne
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

#funkcja do usuwania polskich znaków diakrytycznych
function remove_diacritical_characters([string]$String) {
   $Polish = @('ą', 'ć', 'ę', 'ł', 'ń', 'ó', 'ś', 'ż', 'ź', 'Ą', 'Ć', 'Ę', 'Ł', 'Ń', 'Ó', 'Ś', 'Ż', 'Ź')
   $English = @('a', 'c', 'e', 'l', 'n', 'o', 's', 'z', 'z', 'A', 'C', 'E', 'L', 'N', 'O', 'S', 'Z', 'Z')
   $changed = $String
   foreach ($letter in $changed.toCharArray()) {
      for ($i = 0; $i -lt 19; $i++) {
         if ($letter.ToString().Equals($Polish[$i])) {
            $changed = $changed.Replace($Polish[$i], $English[$i])
         }
      }
   } 
   $changed
}
# Funkcja przygotowująca moduły
function prepare_modules {
   Install-Module -Name AzureAD;
   Import-Module AzureAD;
}
# Funkcja łącząca do Azure
function connect_to_azure {
   Connect-AzureAD -TenantId xxxxxxxx
}
# Generator haseł
function New-RandomPassword {
   param(
      [Parameter()]
      [int]$MinimumPasswordLength = 10,
      [Parameter()]
      [int]$MaximumPasswordLength = 20,
      [Parameter()]
      [int]$NumberOfAlphaNumericCharacters = 5,
      [Parameter()]
      [switch]$ConvertToSecureString
   )
   
   Add-Type -AssemblyName 'System.Web'
   $length = Get-Random -Minimum $MinimumPasswordLength -Maximum $MaximumPasswordLength
   $password = [System.Web.Security.Membership]::GeneratePassword($length, $NumberOfAlphaNumericCharacters)
   if ($ConvertToSecureString.IsPresent) {
      ConvertTo-SecureString -String $password -AsPlainText -Force
   }
   else {
      $password
   }
}

# Funkcja tworząca użytkownika
function add_user_from_file {
   $csv = Import-Csv -Path '.\users.csv' -Encoding UTF8;
   foreach ($user in $csv) {
      $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
      $plain_password = New-RandomPassword
      $password = ConvertTo-SecureString -AsPlainText $plain_password -Force
      $PasswordProfile.Password = $password
      Write-Host "Creating: "$user.imie $user.nazwisko " Mail: " "$(remove_diacritical_characters -String "$($user.imie).$($user.nazwisko)")@sekulawiwitedu.onmicrosoft.com"  " Password: " $plain_password
      New-AzureADUser -DisplayName "$($user.imie) $($user.nazwisko)" -Department $user.dzial  -PasswordProfile $PasswordProfile -City $user.miasto -Country $user.kraj -PreferredLanguage PL-pl -AccountEnabled $true -MailNickName "$(remove_diacritical_characters -String "$($user.imie).$($user.nazwisko)")" -UserPrincipalName "$(remove_diacritical_characters -String "$($user.imie).$($user.nazwisko)")@sekulawiwitedu.onmicrosoft.com" | Out-Null
   }
}
# Funkcja tworząca grupę
function create_group {
   param (
      $GroupName
   )
   New-AzureADGroup -MailNickName $GroupName -DisplayName $GroupName -Description "Group created by script" -MailEnabled $false -SecurityEnabled $true | Out-Null
   Write-Host "Group created: $GroupName"
}
prepare_modules
connect_to_azure
add_user_from_file
create_group -GroupName "IT"
create_group -GroupName "HR"
create_group -GroupName "Administracja"

# Przypisanie użytkwowników do grup
$ad_users = $(Get-AzureADUser -All $true)
foreach ($user in $ad_users) {
   switch ($user.Department) {
      "IT" { Write-Host "Adding $($user.DisplayName) to IT group"; Add-AzureADGroupMember -ObjectId $(Get-AzureADGroup | Where-Object { $_.DisplayName -eq "IT" }).ObjectId -RefObjectId $user.ObjectId }
      "HR" { Write-Host "Adding $($user.DisplayName) to HR group"; Add-AzureADGroupMember -ObjectId $(Get-AzureADGroup | Where-Object { $_.DisplayName -eq "HR" }).ObjectId -RefObjectId $user.ObjectId }
      "Administracja" { Write-Host "Adding $($user.DisplayName) to Administracja group"; Add-AzureADGroupMember -ObjectId $(Get-AzureADGroup | Where-Object { $_.DisplayName -eq "Administracja" }).ObjectId -RefObjectId $user.ObjectId }
      Default { Write-Host "$($user.Department) missing in groups. User: $($user.DisplayName)" }
   }
}
