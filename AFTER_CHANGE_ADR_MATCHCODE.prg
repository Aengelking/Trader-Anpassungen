PROC HOOK_AFTER_CHANGE_ADR_MATCHCODE(cOldMatch,cMatch,cGroup)
   LOCAL nOrd := ku->(IndexOrd())
   LOCAL oAddress := Adresse():New(.F.),oExtra,oCustom
   LOCAL oAdmin
   
   
   HB_SYMBOL_UNUSED(cOldMatch)

   oAddress:LoadMatchcode(cMatch,cGroup)
   oExtra := ku->(ExtraData():New(oAddress:Nummer))
   IF ! Empty(oExtra:AgorumID)      
      TxtBox("Agorum Core wird aktualisiert")
      oCustom := AgorumCustomApi():New()
      IF ! oCustom:SaveAddress(oAddress)
         Tr_MsgBox({"Fehler beim speichern der Adresse in Agorum Core.",oCustom:cErrorText})
      ENDIF
      IF Left(cOldMatch,2) != Left(cMatch,2)
         oAdmin := User():New()         
         IF oAdmin:Load(GetValue("AGORUM_ADMIN",9,"Administrator Benutzer")) .AND. oAdmin:Aktive .AND. ! Empty(oAdmin:Email)
            SendMail({{oAdmin:Email,Trim(oAdmin:Buyer)}},"Adressordner in Agorum verschieben","Alter Matchcode: "+cOldMatch+Chr(10)+Chr(13)+"Neuer Matchcode: "+cMatch+Chr(10)+Chr(13)+"Gruppe: "+cGroup)
         ENDIF
      ENDIF
      TxtClear()
   ENDIF

   ku->(dbSetOrder(nOrd))
   
RETURN

#include "X:\run\agorum.prg"