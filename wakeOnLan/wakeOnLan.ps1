# # Date : 11/02/2015
# Auteur : C. FOUQUET
# Description  : 
# Démarrage de postes par WOL 
# 
# 
# Fichier en entrée : NomPoste,AdresseMAC -> exemple: PC00001,64:31:50:05:38:37
# Description : description des postes pour insertion dans l'objet et le corps du message
# Sources et liens : 
#    http://en.wikipedia.org/wiki/Wake-on-LAN#Magic_packet 
#    https://gallery.technet.microsoft.com/scriptcenter/Wake-On-Lan-815424c4


param(
       [Parameter(Mandatory=$true, HelpMessage="Fichier CSV (chemin complet) contenant les noms et adresses MAC au format XX:XX:XX:XX:XX:XX des postes à réveiller.")]
       [string] $FichierPostes,

       [Parameter(Mandatory=$true, HelpMessage="Description de la liste des postes à réveiller.")]
       [string] $DescriptionPostes

     )

$encoding=[System.Text.Encoding]::UTF8

$Script:MsgRetour= "Réveil des postes " + $DescriptionPostes + " - $(Get-Date -format "dd/MM/yyyy HH:mm:ss") : " + "`n`r"

$Script:Erreurs= $Null

try
    {
        $ListePostes=Import-Csv $FichierPostes -Delimiter ";"

        
    }
    Catch
    {
        # Traitement abandonné : le nom de fichier fourni n'est pas valide
        $Script:Erreurs+="Le fichier " + $FichierPostes + " n'est pas valide.`n"
        continue               
    }

foreach($Poste in $ListePostes)
    { 
    $Nom = $Poste.NomPoste
    $Mac = $Poste.AdresseMAC
    
    if (!($Mac -like "*:*:*:*:*:*") -or ($mac -like "*-*-*-*-*-*"))
        {$Script:Erreurs+="L'adresse MAC " + $Mac + " du poste "+ $Nom + " n'est pas valide. Le poste n'a pas été traité.`n"}
        
        Else 
            {
                # Construction du Magic packet 
                $MaChaineMac=@($Mac.split(":""-") | foreach {$_.insert(0,"0x")})
                $MaCible = [byte[]]($MaChaineMac[0], $MaChaineMac[1], $MaChaineMac[2], $MaChaineMac[3], $MaChaineMac[4], $MaChaineMac[5])
                
                # Le Magic Packet et une trame de broadcast contenant 6 octets à 255 (FF FF FF FF FF FF en hexadecimal)
                $MagicPacket = [byte[]](,0xFF * 102)
                # suivis de seize répétitions de l'adresse MAC du poste cible (sur 48 bits soit un total de 102 bytes).
                6..101 |% { $MagicPacket[$_] = $MaCible[($_%6)]}
    
                
                try 
                {
                
                # Utilisation du framework.NET pour créer un socket UDP permettant l'envoi de la trame
                $UDPclient = new-Object System.Net.Sockets.UdpClient
                $UDPclient.Connect(([System.Net.IPAddress]::Broadcast),4000)
                $UDPclient.Send($MagicPacket, $MagicPacket.Length) | out-null
                }
                    catch
                    { $Script:Erreurs+="Impossible d'envoyer la demande de réveil (magic packet) au poste "+ $Nom + ".`n" 
                      continue  

                    }            

            }
}

Start-Sleep -s 60

foreach($Poste in $ListePostes)
    {
        if (Test-Connection -computer $Poste.NomPoste -quiet)
        {$Script:MsgRetour+="Le poste "+ $Poste.NomPoste + " est disponible.`n"}
        
        Else
            {$Script:Erreurs+="Le poste "+ $Poste.NomPoste + " n'est pas disponible.`n"

            }

    }


if ($Script:Erreurs) {$Script:MsgRetour+= "`n`r" + " Erreurs détectées : `n" + $Script:Erreurs} 
send-mailmessage -from "sidsic-spvr <sidsic-spvr@indre-et-loire.gouv.fr>" -to "sidsic-spvr <sidsic-spvr@indre-et-loire.gouv.fr>" -subject "[Pref37-sinfra1] Reveil des postes  $DescriptionPostes - $(Get-Date -format "dd/MM/yyyy HH:mm:ss")" -body $Script:MsgRetour -smtpServer pref.mel37.si.mi -Encoding $encoding
  
