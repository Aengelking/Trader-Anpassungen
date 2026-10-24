PROC HOOK_AFTER_SAVE_CONTACT(lNew,oContact)
   LOCAL oAddress,oCustom
   LOCAL cNumber
//Alert("Contact has been edited "+IF(lNew,"NEW",""))

NetUse("phonebook","pbk")
pbk->(dbSetOrder(2))

cNumber := ""
If At("-",conts->Telephone) == 1
   cNumber := SubStr(ku->Telefon,0,RAt("-",ku->Telefon)-1)+conts->Telephone
Elseif ! Empty(conts->Telephone)
   cNumber := conts->Telephone
ELSEIF ! Empty(conts->Mobile)
   cNumber := conts->Mobile
EndiF
IF ! pbk->(dbSeek( Str(conts->Address,6)+Str(conts->Number,4) ))   
   pbk->(Add_Rec(0))
   pbk->Address := conts->Address
   pbk->Contact := conts->Number
ELSE
   pbk->(Rec_Lock(0))
ENDIF
pbk->Number := NormalizeTelNo(cNumber)
pbk->(dbUnLock())
IF SystemUSer():ID == 9
   //Alert(pbk->Number)
ENDIF

IF lNew .OR. oContact:FieldUpdatedLastSave("EMAIL")
   oAddress := Adresse():New()   
   oAddress:Load(oContact:Address)
   IF oAddress:nRecno != 0 .AND. oAddress:Group $ {"K","L"}
      TxtBox("Agorum Core wird aktualisiert")
      oCustom := AgorumCustomApi():New()
      IF ! oCustom:SaveAddress(oAddress)
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Fehler beim Speichern der Adresse in Agorum Core","Adresse: "+LTrim(Str(oAddress:Nummer))+Chr(10)+Chr(13)+oCustom:cErrorText)
         //Tr_MsgBox({"Fehler beim Speichern der Adresse in Agorum Core.",oCustom:cErrorText})
      ENDIF
      TxtClear()
   ENDIF
   
ENDIF


#include "X:\run\agorum.prg"
