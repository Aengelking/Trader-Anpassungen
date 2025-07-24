FUNC HOOK_ON_SEND_PAYREMINDER(cState,cKunde,cText,nMaxDaysOver,nMaxRem,aOpenInvoices)
   LOCAL oExtra,oKunde,cText2,aRecvs := {}
   LOCAL nPerson := 0,aTo,aTos
   LOCAL cType,nTotal

   ? cKunde

   HB_SYMBOL_UNUSED(cState)

   oKunde := Adresse():New()
   oKunde:LoadMatchcode(cKunde,"K")
   oKunde:gotoRec()
   oExtra := ku->(ExtraData():New(oKunde:Nummer))
   IF nMaxDaysOver <= 0
      cType := "Kontoauszug"
   ELSE
      cType := "Mahnung"
   ENDIF
   IF oExtra:AutoMahn .AND. nMaxRem < 3 .AND. AddWorkingDays(GetValue("LASTPAY","D"),2,GetConfigValue("STATE"),.T.) >= Date() 
      IF GetCustomerCredit() >= 0
         SendMail({{"amos.engelking@engelking.de","Amos"}},cType+" wurde NICHT an "+Trim(cKunde)+" versendet",cText,,,2,.T.)
      ELSE
         cText2 := "<b>"+cType+" WURDE VERSENDET</b><br/><br/>"
         IF nMaxDaysOver > 0
            cText2 += "Mahnstufe: "+LTrim(Str(nMaxRem+1))+"<br/>"
         ENDIF
         cText2 += "Empf„nger: <br/>"
         
         NetUse("contacts","conts")
         conts->(dbSetOrder(2))
         conts->(dbSeek( Str(oKunde:Nummer,6) ))   

         DO WHILE ! conts->(Eof()) .AND. conts->Address == oKunde:Nummer
            IF conts->Active .AND. conts->Accounts  .AND. ! Empty(conts->Email)
               cText2 += Trim(conts->Name)+" ("+Trim(conts->email)+")<br/>"
               IF nPerson == 0
                  nPerson := conts->Number
               ELSE
                  Aadd(aRecvs,{"TO",Trim(conts->email)})
               ENDIF
               
            ENDIF
            conts->(dbSkip())
         ENDDO
         
         cText2 += "<br/>"+cText

         IF nPerson != 0
            nTotal := 0
            AEval(aOpenInvoices,{|x| 
               nTotal += x["VALUE"]
               RETURN .T.
            })
            IF nTotal > 5 //erst ab 5 EUR
               SetPrinterMethodType(3)
               StatDr(cKunde,nPerson,3,AddWorkingDays(GetValue("LASTPAY","D"),-1,GetConfigValue("STATE"),.T.),aRecvs)   
               
               //aTo := 
               //aTo := GetConfigEmail("SI-NOPAY-SEVERE")
               //Aadd(aTo,GetConfigEmail("SI-NOPAY-SEVERE"))
               aTos := {GetConfigEmail("SI-NOPAY")}
               IF nMaxRem >= 2
                  Aadd(aTos,GetConfigEmail("SI-NOPAY-SEVERE"))
               ENDIF
               FOR EACH aTo IN aTos
                  SendMail(aTo,cType+" wurde an "+Trim(cKunde)+" versendet",cText2,,,2,.T.)
               NEXT
               RETURN .F. //do not send standard email
            ENDIF
         ENDIF
      ENDIF
   ENDIF
RETURN .T.