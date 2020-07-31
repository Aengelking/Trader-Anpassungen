PROCEDURE RUN_DAVID_CONTEXT( cFunction,cMsgPath )
   LOCAL nAngnr := 0
   LOCAL getlist := {}

   SWITCH Upper(cFunction)
      CASE "INVOICE"
         MBaseRun(Trim(tr_getini(1))+"\run\Invoice_beleg",{"CONTEXT",cMsgPath})
         EXIT
      CASE "NOTIZ"
         MBaseRun(Trim(Tr_getini(1))+'\run\notiz')
         EXIT
      CASE "BESCHK"
         MBaseRun(Trim(Tr_getini(1))+'\run\BesChk',{cMsgPath})
         EXIT
      CASE "ENQUIRY"
         Enquiry()
         EXIT
      CASE "AUFTRAG"
         MBaseRun(Trim(tr_getini(1))+"\run\Auftrag_Beleg",{cMsgPath})
         EXIT
      CASE "ANGEBOT"
         Head("Angebot in Auftrag wandeln")
         NetUse("angebot","ang")
         @ 01,00 SAY "Angebot" GET nAngnr PICTURE "999999" VALID {||
            LOCAL lRet
            ang->(dbSetOrder(1))
            ang->(dbSetFilter({|| ang->Bestat < 3 },"bestat < 3"))
            lRet := ang->(dbSeek( Str(nAngnr,6) ))            
            ang->(dbClearFilter())
            IF lRet
               @ 01,14 CLEAR
            ELSE
               @ 01,14 SAY "Nicht gefunden"
            ENDIF
            RETURN lRet
         }
         READ
         IF LastKey() != 27
            Engauft(,nAngnr)
            IF Tr_MsgBox(t("Angebot schließen?"),,{"Nein","Ja"}) == 2

               ang->(dbSeek(Str(nAngnr,6)))
               DO WHILE ang->Angnr == nAngnr .AND. ! ang->(EOF())
                  IF ang->Bestat < 3
                     ang->(Rec_Lock())
                     ang->Bestat := 3
                     ang->(dbUnLock())
                     ang->(dbSkip())
                  ENDIF
               ENDDO
            ENDIF
         ENDIF
         EXIT
   END