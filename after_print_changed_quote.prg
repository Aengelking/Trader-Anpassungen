PROC HOOK_AFTER_PRINT_CHANGED_QUOTE(nAngnr,cPDF)

LOCAL lFirst := .T.
LOCAL aValues,dDate,aAttach,cText,aContact
LOCAL lNoCrm := .T. //Tr_Getini(28) $ {9,33,28,58}
// CRM (Transition): Angebot als Aktivit�t an die verkn�pfte Opportunity melden.
// L�uft zus�tzlich zum noCRM-Pfad. Aktivieren: lCrmQuotes := Tr_Getini(28) $ {9,33,28,58}
LOCAL lCrmQuotes := .F.

aValues := EnquiryAddUp(nAngnr,.T.)
aAttach := {}

If ! Empty(cPDF)
   aAttach := {cPDF}
Endif
cText := "Angebot: "+LTrim(Str(nAngNr))+Chr(13)+Chr(10)
cText += "Kunde: "+ku->Name1+Chr(13)+Chr(10)
aContact := GetContact(ang->Person)
cText += "Ansprechpartner: "+aContact["name"]+Chr(13)+Chr(10)
cText += "Telefon: "+aContact["fullphone"]+Chr(13)+Chr(10)
cText += "Wert: "+LTrim(Str(aValues[2],12,2))+Chr(13)+Chr(10)
cText += "Gedruckt am: "+DToC(Date())

// CRM (Transition): Text-Aktivit�t "Angebot gedruckt" an die zugeordnete
// Opportunity h�ngen (Zuordnung erfolgte in before_print_angebot). Best-effort.
IF lCrmQuotes
   BEGIN SEQUENCE
      LoadPrg(Path("run\crm_email.prg"))
      HB_ExecFromArray({"CRM_QuoteReport", nAngnr, aValues[2], cText})
   RECOVER
      //nicht fatal
   END SEQUENCE
ELSE

   IF ! lNoCrm
      

      dDate := Date()+7  //allgemein eine Woche
      If aValues[2] > 500 //the quote is at least worth 500 EUR
         If DoW(dDate) > 3  //it is wednesday or later
            dDate := Date()+5  //add weekend
         Else
            dDate := Date()+3
         Endif
      Endif

      While lFirst .OR. LastKey() == 27 .OR. dDate < Date()+1
         dDate := GetBox(dDate,"Wiedervorlage")
         lFirst := .F.
      End
   
      AddWiedervorlage(dDate,"Wiedervorlage Angebot "+LTrim(Str(nAngNr))+" "+ku->Name1,cText,"ANG:"+ku->Kunde+Str(nAngNr,6),aAttach)
   ELSE
      ang->(dbSetOrder( 1 ))
      ang->(dbSeek( Str(nAngnr,6) ))
      noCRM_Interface()
   ENDIF
ENDIF

If aValues[1] > 3000 //Nachricht an Thimo
   SendMail({{"thimo.hamma@engelking.de","Thimo"}},"Interessantes Angebot "+LTrim(Str(nAngNr))+" "+ku->Name1,cText,aAttach)   
Endif

#include 'x:\run\nocrm.prg'
