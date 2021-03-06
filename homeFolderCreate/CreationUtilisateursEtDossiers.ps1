# # Date : 21/02/2017
# Auteur : C. FOUQUET
# Description  : 
# Création des comptes utilisateurs à partir d'un fichier CSV dans l'OU spécifiée 
# Si requis, création du Homedir et affectation des permissions avec sous-dossier Keepass
# Si requis, création du dossier de messagerie et affectation des permissions, avec sous-dossiers contenant la redirection ImapMail, les archives et signatures 
# Si requis, affectation au groupe CPIC37_UtilisateursAvecProfilsItinerants pour création d'un dossier de profil itinérant par GPO sur \\giprc-scpic3703\Profil$ et accès au dossier
#
# Fichier .csv : import_users.csv
# Emplacement : dans le dossier d'exécution du script 
# Structure : 
# - Company 
# - City
# - Department
# - Description
# - DisplayName
# - EmailAddress
# - GivenName
# - Path
# - mail
# - Name
# - OfficePhone
# - POBox
# - PostalCode
# - SamAccountName
# - sn
# - StreetAddress
# - Surname
# - telephoneNumber
# - Title
# - UserPrincipalName
# - Password
# - CreerHomedir
# - CreerDossiersMessagerie
# - ProfilItinerant

#------------------------------------------------------------------------------------------
# Définition des paramètres pour les différents types de dossiers (OPTIMISABLE AVEC TABLEAU ASSOCIATIF A PLUSIEURS DIMENSIONS)
#------------------------------------------------------------------------------------------
# Déclaration des tableaux associatifs pour chaque paramètre 
#------------------------------------------------------------------------------------------
# Emplacement des dossiers pour chaque type :
$CheminDossier = @{} 
# Groupe AD autorisé pour chaque type :
$GroupeAccesDossier = @{}
# Arborescence normalisée pour chaque type (tableau de tableaux) :
$ArboDossier = @{}
#------------------------------------------------------------------------------------------
# Population des tableaux 
#------------------------------------------------------------------------------------------
# Pour les Homedirs : 
$CheminDossier +=@{Homedir="\\giprc-scpic3703\Homedirs$\"}
$GroupeAccesDossier +=@{Homedir="CPIC37_Utilisateurs"}
$ArboDossier += @{Homedir=[string[]]$SousDossiers="Keepass"}
# Pour les dossiers de messagerie : 
$CheminDossier +=@{Messagerie="\\giprc-scpic3703\Messagerie$\"}
$GroupeAccesDossier +=@{Messagerie="CPIC37_UtilisateursMessagerie"}
$ArboDossier += @{Messagerie=[string[]]$SousDossiers="IMAPMail","Archives","Signatures"}
# Pour les profils itinérants, groupe uniquement (arborescence sans objet et chemin défini par GPO) : 
$GroupeAccesDossier +=@{ProfilsItinerants="CPIC37_UtilisateursAvecProfilsItinerants"}
#------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------
# Variables par défaut pour affectation de permissions sur les dossiers créés :
#------------------------------------------------------------------------------------------
# Ici -> contrôle total pour l'utilisateur désigné avec désactivation de l'héritage du dossier parent, propagation à outs le conteneurs et objtes enfants
# Type de permissions -> Define FileSystemAccessRights: Contrôle total
$FileSystemAccessRights = [System.Security.AccessControl.FileSystemRights]"FullControl"
# Propagation de l'héritage sur les enfants : activé sur les conteneurs et les objets enfants 
$InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::"ContainerInherit", "ObjectInherit"
# Permissions héritées du dossier parent -> héritage désactivé
$PropagationFlags = [System.Security.AccessControl.PropagationFlags]::None
# Type d'accès créé (autorisé ou refusé : autorisé 
$AccessControl =[System.Security.AccessControl.AccessControlType]::Allow 
#------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------
# Autres variables du script
#------------------------------------------------------------------------------------------
# Chemin du dossier d'exécution du script pour accès aux fichiers .CSV et .log (par défaut dans le même dossier)
$ScriptPath = Split-Path -parent $MyInvocation.InvocationName

# Nom du fichier .CSV à importer (par défaut dans le même dossier que le script)
$NomFichierCSV = "import_users.csv"

# Nom du fichier log (par défaut dans le même dossier que le script)
$NomFichierLog = "CreationUtilisateursEtDossiers_" + "{0:yyyy-MM-dd_HH-mm-ss}" -f (Get-Date) +".log"

# Chemin complet du fichier .CSV
$FichierCSV = $ScriptPath + "\" + $NomFichierCSV

# Chemin complet du fichier .log
$FichierLog  = $ScriptPath + "\CreationUtilisateursEtDossiers_" + "{0:yyyy-MM-dd_HH-mm-ss}" -f (Get-Date) +".log"

# Date
$MaDate = Get-Date

# Domaine AD 
$Domaine = 'cpic37'


# Import du module Powershell ActiveDirectory pour utilisation des objets et cmdlets correspondants 
Import-Module ActiveDirectory

#------------------------------------------------------------------------------------------
Function CreerDossierIndividuel 
# Description :
# Créé le dossier, affecte les permissions à l'utilisateur propriétaire et l'intègre au groupe permettant d'accéder au partage contenant le dossier
# Paramètres :
# - TypeDossier : permet de rechercher dans les tableaux déclarés en variable du script : le chemin du dossier, le groupe pour accéder au partage, l'arborescence à créer
# - NomDossier : nom du dossier à créer 
# - CompteUtilisateur : samAccountName de l'utilisateur pour affectation des permissions

{
    param([string]$TypeDossier, [string]$NomDossier, [string]$CompteUtilisateur, [string]$FichierLogParent)
    
    $MonDossier = $CheminDossier[$($TypeDossier)]+$NomDossier
    $MonUTilisateur = $Domaine + "\" + $CompteUtilisateur
    
    Try 
        {
         #--------------------------------------------------------------------------------------
         # Création du dossier 
         #--------------------------------------------------------------------------------------
         New-Item -ItemType Directory -Path $MonDossier
         #--------------------------------------------------------------------------------------
         "Dossier $($TypeDossier) créé sous $($MonDossier) : `n" | Out-File $FichierLogParent -append

         #--------------------------------------------------------------------------------------
         # Affectation des permissions
         #--------------------------------------------------------------------------------------
         # Création de la nouvelle règle d'accès  à appliquer au dossier (cf. variables en début de script pour les paramètres par défaut utilisés)
         $MonAccessrule = New-Object System.Security.AccessControl.FileSystemAccessRule `
         ($MonUtilisateur , $FileSystemAccessRights, $InheritanceFlags, $PropagationFlags, $AccessControl) 
    
         # Récupération de l'ACL existante
         $MonACL = Get-ACL -path $MonDossier
    
         # Application de la nouvelle règle d'accès à l'ACL existante
         $MonACL.SetAccessRule($MonAccessrule)

         # Affecte les permissions sur le dossier
         Set-ACL -path $MonDossier -AclObject $MonACL
         " - permissions affectées sur le dossier $($MonDossier)`n" | Out-File $FichierLogParent -append
         #--------------------------------------------------------------------------------------

         #--------------------------------------------------------------------------------------
         # Création de l'arborescence
         #--------------------------------------------------------------------------------------
         $MesSousDossiers = $ArboDossier[$TypeDossier]
         foreach ($SousDossier in $MesSousDossiers)
             {
               $MonSousDossier = $MonDossier + "\" + $SousDossier
               New-Item -ItemType Directory -Path $MonSousDossier
               " - sous-dossier $($MonSousDossier) créé `n" | Out-File $FichierLogParent -append

             }
         #--------------------------------------------------------------------------------------
         
         #--------------------------------------------------------------------------------------
         # Ajout de l'utilisateur au groupe d'accès au partage contenant le type de dossier
         #--------------------------------------------------------------------------------------
         Add-ADGroupMember $GroupeAccesDossier[$TypeDossier] $CompteUtilisateur
         " - utilisateur ajouté au groupe $($GroupeAccesDossier[$TypeDossier])`n" | Out-File $FichierLogParent -append
         #--------------------------------------------------------------------------------------

    }
    Catch
        { "Erreur lors de la création du dossier dossier $($TypeDossier) $($MonDossier) :`n" | Out-File $FichierLogParent -append
          "$Error[0]"  | Out-File $FichierLogParent -append
        }
         "---------------------------------------------------------------------------------------------------" | Out-File $FichierLog -append        
}


Function CreerUtilisateurActiveDirectory
{
# Ligne d'entête du log pour l'occurrence d'exécution du script -> ajout au fichier s'il existe
"$MaDate - Création d'utilisateurs Active Directory et de leurs dossiers individuels : " | Out-File $FichierLog -append


# Lecture et chargement du fichier csv 


  Import-CSV $FichierCSV -Delimiter ';' | ForEach-Object `
   {

      #------------------------------------------------------------------------------------------
      # # Création du compte utilisateur à partir des champs du fichiers .CSV 
      # Améliorations à apporter : contrôle de la validité des informations du fichier csv -> récupération du 
      # code erreur de l'exécution de New-ADUser
      #------------------------------------------------------------------------------------------

      # Convertit le mot de passe passé en clair dans le fichier .CSV en chaîne sécurisée
      $MotDePasseCrypte= ConvertTo-SecureString -AsPlainText $_.Password -force

      
        Try
           {New-ADUser -Name $_.DisplayName -SamAccountName $_.SamAccountName -GivenName $_.GivenName `
            -Surname $_.sn -DisplayName $_.DisplayName -Office $_.OfficeName `
            -Description $_.Description -EmailAddress $_.mail `
            -StreetAddress $_.StreetAddress -City $_.City `
            -PostalCode $_.PostalCode -UserPrincipalName $_.UserPrincipalName `
            -Company $_.Company -Department $_.Department -POBox $_.POBox -Title $_.Title`
            -OfficePhone $_.telephoneNumber -AccountPassword $MotDePasseCrypte -Enabled $true -Path $_.Path  
  
             # Utilisateur créé - écriture de l'information dans le log
            "`n---------------------------------------------------------------------------------------------------" | Out-File $FichierLog -append
            "Utilisateur : " + $_.DisplayName + "`n" | Out-File $FichierLog -append
            "---------------------------------------------------------------------------------------------------" | Out-File $FichierLog -append
            #------------------------------------------------------------------------------------------
            # Création du homedir si demandée (champ CreerHomedir=Oui dans .CSV)
            #------------------------------------------------------------------------------------------
            if($_.CreerHomedir="Oui") 
               {
                CreerDossierIndividuel 'Homedir' ($_.sn + '.' + $_.GivenName).ToLower() $_.samAccountName $FichierLog 
               }
               else {" - création du homedir non demandée`n"| Out-File $FichierLog -append}

           #------------------------------------------------------------------------------------------
           # Création du dossier de messagerie si demandée (champ CreerDossiersMessagerie=Oui dans .CSV)
           #------------------------------------------------------------------------------------------
           if($_.CreerDossiersMessagerie="Oui") 
            {
             CreerDossierIndividuel 'Messagerie' ($_.sn + '.' + $_.GivenName).ToLower() $_.samAccountName $FichierLog
            }
            else {" - création des dossiers de messagerie non demandée`n " | Out-File $FichierLog -append}

           #------------------------------------------------------------------------------------------
           # Affectation de profil itinérant si demandée (champ ProfilItinerant=Oui dans .CSV)
           # Création du dossier et des permissions automatiques (GPO)
           # Pas d'arborescence spécifique à créer
           # seule l'affectation au groupe permettant l'accès au partage Profil$ est nécessaire
           #------------------------------------------------------------------------------------------
           if($_.ProfilItinerant="Oui") 
            {
             Add-ADGroupMember $GroupeAccesDossier['ProfilsItinerants'] $_.samAccountName
             " Profil itinerant : `n" | Out-File $FichierLog -append
             " - utilisateur ajouté au groupe $($GroupeAccesDossier['ProfilsItinerants']) `n" | Out-File $FichierLog -append
            }
            else {" - pas de profil itinérant demandé`n"| Out-File $FichierLog -append }

        }
        Catch 
            {" Erreur : " +  $Error[0].ToString() | Out-File $FichierLog -append              
            }
        Finally 
            {
             $LigneFichierLog | Out-File $FichierLog -append
            }
                  
   
  "---------------------------------------------------------------------------------------------------" | Out-File $FichierLog -append
}
}

# Exécute la fonction principale 

CreerUtilisateurActiveDirectory


  