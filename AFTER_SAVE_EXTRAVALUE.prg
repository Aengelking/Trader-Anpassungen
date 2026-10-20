Function AFTER_SAVE_EXTRAVALUE(cName,oExtra)
   LOCAL oArt
   IF oExtra:cDBID == "KU"
      IF oExtra:WerksBesch .AND. Empty(oExtra:ShpNtfyTo)
         Tr_MsgBox("EmpfÑnger fÅr Versandmitteilung hinterlegen, Werkbescheinigung wird dorthin gesendet.")
      ENDIF
      IF oExtra:WerksBesch .AND. ! oExtra:Shipnotify
         oExtra:Shipnotify := .T.
         oExtra:Save()
         Tr_MsgBox("Versandmitteilung wurde fÅr Werksbescheinigung aktiviert.")
      ENDIF

      /*  Wird hier das Kennzeichen FACTORING gesetzt, den Kunden gleich bei
       *  Tilta einrichten. Sonst passierte das erst beim nÑchsten Speichern
       *  der Adresse, und bis dahin gÑbe es weder Buyer noch FazilitÑt -
       *  Rechnungen dieses Kunden liefen also ins Leere.
       *
       *  Nur beim Setzen, nicht bei jeder anderen Variablen: das Setup kostet
       *  mehrere API-Aufrufe. Was es anlegt, steht in run\tilta_hook.prg.  */
      IF Upper(AllTrim(cName)) == "FACTORING" .AND. oExtra:Factoring         
         __TiltaSetupKunde(oExtra:nID)
      ENDIF
   ELSEIF oExtra:cDBID == "ART"
      IF oExtra:Gef_H225 .AND. ! oExtra:Gefahr
         oExtra:Gefahr := .T.
         oExtra:Save()
         //Tr_MsgBox("Gefahrstoffe mÅssen als solche gekennzeichnet werden")
      ENDIF
      IF oExtra:Gefahr .AND. ! oExtra:SDS
         oExtra:SDS := .T.
         oExtra:Save()
         Tr_MsgBox("Sicherheitsdatenblatt ist bei Gefahrstoffen notwendig")
      ENDIF
      IF oExtra:Critical .AND. ! art->Charge
         oArt := Artikel():New()
         oArt:Charge := .T.
         oArt:Save()
         Tr_MsgBox("Chargenverwaltung fÅr kritische Komponente aktiviert")
      ENDIF
      IF oExtra:Expires .AND. ! art->Charge
         oArt := Artikel():New()
         oArt:Charge := .T.
         oArt:Save()
         Tr_MsgBox("Chargenverwaltung fÅr Artikel mit Verfallsdatum aktiviert")
      ENDIF
   ENDIF
RETURN .T.

#include "x:\run\tilta_hook.prg"
