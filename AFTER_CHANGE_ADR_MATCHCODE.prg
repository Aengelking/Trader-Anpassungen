PROC HOOK_AFTER_CHANGE_ADR_MATCHCODE(cOldMatch,cMatch,cGroup)
   LOCAL nOrd 
   LOCAL oAddress,oExtra,oCustom
   LOCAL oAdmin
   IF Select("ku") == 0
      NetUse("engkund","ku")
   ENDIF
   nOrd := ku->(IndexOrd())
   oAddress := Adresse():New(.F.)
   
   
   HB_SYMBOL_UNUSED(cOldMatch)

   oAddress:LoadMatchcode(cMatch,cGroup)
   oExtra := ku->(ExtraData():New(oAddress:Nummer))
   IF ! Empty(oExtra:AgorumID)      
      TxtBox("Agorum Core wird aktualisiert")
      oCustom := AgorumCustomApi():New()
      IF ! oCustom:ChangeMatchcode(oAddress,cOldMatch)         
         Tr_MsgBox({"Fehler beim speichern der Adresse in Agorum Core. Administrator wird informiert.",oCustom:cErrorText})
         oAdmin := User():New()         
         IF oAdmin:Load(GetValue("AGORUM_ADMIN",9,"Administrator Benutzer")) .AND. oAdmin:Aktive .AND. ! Empty(oAdmin:Email)
            SendMail({{oAdmin:Email,Trim(oAdmin:Buyer)}},"Fehler beim „ndern des Matchcodes der Adresse "+LTrim(Str(oAddress:Nummer))+" in Agorum Core.",oCustom:cErrorText)
         ENDIF
      ENDIF
      TxtClear()
   ENDIF

   ku->(dbSetOrder(nOrd))
   
RETURN

//#include "X:\run\agorum.prg"