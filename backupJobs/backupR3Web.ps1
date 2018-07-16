# Date : 01/09/2014
# Auteur : C. FOUQUET
# Description  : 
# Sauvegarde online complète des bases de données du serveur PREF37-SAPP1
# $RemBkpSrvRootFolder: chemin du dossier racine sur serveur de sauvegarde distant
# $MsgRetour

# Chargement des assemblys (fonctions) SMO nécessaires (SMO - Server Management Object : composants Powershell optionnels pour la gestion des serveurs)
 [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null            
 [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null            
 [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.ConnectionInfo") | Out-Null             
 [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoEnum") | Out-Null             

# Définition du chemin de base sur pref37-sbackup2
$RemBkpSrvRootFolder = "\\pref37-sbackup2\backup\"

# Définition du format d'encodage du corps du message envoyé en fin de travail
$encoding=[System.Text.Encoding]::UTF8

# Initialisation du contenu du message à envoyer 
$Script:MsgRetour=$Null

#######################################################################
function Backup-Database($DbInstance, $DbName, $RemoteBackupFolder)
#######################################################################
# Fonction générique de création d'un objet sauvegarde avec passage de paramètres
#
# Paramètres en entrée :
# $DbServer : objet instance créé
# $DbName  : nom de la base
# $RemoteBackupFolder : nom du dossier spécifique sur serveur de sauvegarde distant
#
# Variables utilisées :
# $DbServer : objet instance créé
# $DbInstance : nom de l'instance passé en paramètre
# $DbName  : nom de la base
# $File : nom du fichier de sauvegarde

{                          
 # Création de l'objet Server (=instance SQLServer)
 $DbServer = New-Object Microsoft.SqlServer.Management.Smo.Server $DbInstance
   
 # Création de l'objet Backup
 $Bkup = New-Object Microsoft.SqlServer.Management.Smo.Backup
 
 # Création de l'objet Database
 $Bkup.Database = $DbName
  
 # Nom du jeu de sauvegarde
 $Bkup.BackupSetName= $DbName + "_Complete"
    
 # Récupération du n° de jour dans la semaine pour génération du nom du fichier de sauvegarde
 $JourSemaine = Get-Date -uformat %u
 Switch ($JourSemaine)
    {
        1 {$JourSemaine = "Lundi"}
        2 {$JourSemaine = "Mardi"}
        3 {$JourSemaine = "Mercredi"}
        4 {$JourSemaine = "Jeudi"}
        5 {$JourSemaine = "Vendredi"}                            
    }

 # Définition du type de sauvegarde. Database = sauvegarde complète
 $Bkup.Action = [Microsoft.SqlServer.Management.Smo.BackupActionType]::Database             
  
 # S'il existe déjà, suppression (pour éviter l'ajout du jeu dans le même fichier de sauvegarde) puis création de l'objet device (=fichier local) de sauvegarde
 $File = $DbServer.BackupDirectory + "\" + $DbName + "_" + $JourSemaine + ".bak" 
 If ((Test-Path $File)) {Remove-Item $File -Force}
 $Bkup.Devices.AddDevice($File, [Microsoft.SqlServer.Management.Smo.DeviceType]::File)
 
 # Exécution de la sauvegarde locale (dans le dossier Backup par défaut de l'instance)
 $Bkup.SqlBackup($DbInstance)
 $Script:MsgRetour += "Base $DbName sauvegardée : fichier $File (" + ((get-item $File).Length / 1KB) + " Ko) le " + ((get-item $File).LastWriteTime).ToString("dd/MM/yyyy HH:mm:ss") + ".`n"

# Copie du fichier vers le serveur de sauvegarde distant, dans le dossier spécifique
Copy-Item -Path ($File) -Destination ($RemBkpSrvRootFolder + $RemoteBackupFolder) -Force 
$Script:MsgRetour += "Fichier copié vers $RemBkpSrvRootFolder$RemoteBackupFolder le " + $(Get-Date -format "dd/MM/yyyy HH:mm:ss")  + ".`n`r"
 
         
trap [Exception]
 {            
  $Script:MsgRetour += "Base $DbName : " + "`n`r" + $_.Exception.Message
  send-mailmessage -from "sidsic-spvr <sidsic-spvr@indre-et-loire.gouv.fr>" -to "sidsic-spvr <sidsic-spvr@indre-et-loire.gouv.fr>" -subject "[Pref37-sapp1] ERREUR - Sauvegarde du $(Get-Date -format "dd/MM/yyyy HH:mm:ss")" -body $Script:MsgRetour -smtpServer pref.mel37.si.mi -Encoding $encoding
  break            
 }          
    
}            
#######################################################################
           
# Sauvegarde BD R3Web 
  Backup-Database ($env:COMPUTERNAME + "\PREF37R3WEB") "R3Web" "r3web"

# Sauvegarde bases systèmes de l'instance PREF37R3Web
  Backup-Database ($env:COMPUTERNAME + "\PREF37R3WEB") "master" "r3web\BasesSystemes"
  Backup-Database ($env:COMPUTERNAME + "\PREF37R3WEB") "model" "r3web\BasesSystemes"
  Backup-Database ($env:COMPUTERNAME + "\PREF37R3WEB") "msdb" "r3web\BasesSystemes" 
  
# Sauvegarde BD CadManager - en attente migration 
# Backup-Database ($env:COMPUTERNAME + "\CADMANAGER") "R3Web" "r3web"
  
# Sauvegarde bases systèmes de l'instance CADMANAGER - en attente migration 
# Backup-Database ($env:COMPUTERNAME + "\CADMANAGER") "master" "r3web\BasesSystemes"
# Backup-Database ($env:COMPUTERNAME + "\CADMANAGER") "model" "r3web\BasesSystemes"
# Backup-Database ($env:COMPUTERNAME + "\CADMANAGER") "msdb" "r3web\BasesSystemes" 

 
# Test pour lever une exception et générer l'exécution des instructions de 'trap'
# Backup-Database ($env:COMPUTERNAME + "\PREF37R3WEB") "toto" "r3web\BasesSystemes"
    
  # Envoi du message de rapport vers la BAL sidsic-spvr
  send-mailmessage -from "sidsic-spvr <sidsic-spvr@indre-et-loire.gouv.fr>" -to "sidsic-spvr <sidsic-spvr@indre-et-loire.gouv.fr>" -subject "[Pref37-sapp1] Sauvegarde du $(Get-Date -format "dd/MM/yyyy HH:mm:ss")" -body $Script:MsgRetour -smtpServer pref.mel37.si.mi -Encoding $encoding
  
  # Ecriture d'un événement contenant l'objet du message dans le journal Application
  # Remarque : nécessite d'avoir exécuté (1 seule fois) la commande suivante pour créer la source d'événement
  # New-EventLog –LogName Application –Source “C:\Adminscripts\BackupR3Web.ps1”
  # Write-EventLog –LogName Application –Source “C:\Adminscripts\BackupR3Web.ps1” –EntryType Information –EventID 1  –Message $Script:MsgRetour
  
  exit 
