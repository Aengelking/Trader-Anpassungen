PROC RUN_CHECK_APPROVAL
   LOCAL cText,lNot,lFound,lDel,aTo
   LOCAL oAuftrag,lWaitApproval
   LOCAL cBuyer

   NetUse("approval","apr")
   NetUse("engauf","auf")
   NetUse("angebot","ang")
   NetUse("engbes","bes")

   apr->(__dbSetFilter({|| apr->ApprovedBy == 0 .AND. SToD(apr->RequestDa) < Date()-2 }))
   apr->(dbGoTop())

   cText := "Folgende Genehmigungen stehen noch aus:<pre>"
   cText += "<br>Typ"+" "+Pad("Nummer",6)+" "+Pad("Datum",8)+" "+"Uhrzeit"

   lFound := .F.
   DO WHILE ! apr->(EOF())
      lNot := .T.
      lDel := .F.
      IF Trim(apr->Type) == "AUF"
         IF ! auf->(dbSeek( Str(apr->No,6) ))
            lNot := .F.
            lDel := .T.
         ELSEIF auf->Abnr == apr->No .AND. auf->BeStat < 3
            lNot := .F.
         ENDIF
      ELSEIF Trim(apr->Type) == "ANG"
         IF ! ang->(dbSeek( Str(apr->No,6) ))  //Angebot nicht mehr vorhanden
            lNot := .F.
            lDel := .T.
         ELSEIF ang->BeStat == 3
            lNot := .F.
         ENDIF
      ELSEIF Trim(apr->Type) == "BES"
         IF ! bes->(dbSeek( Str(apr->no,6) ))
            lNot := .F.
            lDel := .T.
         ENDIF
      ENDIF
      IF lDel
         apr->(Rec_Lock(0))
         apr->(dbDelete())
         apr->(dbUnLock())
      END
      IF lNot
         lFound := .T.
         cText += "<br>"+apr->Type+" "+Str(apr->no,6)+" "+Left(TtoC(SToT(apr->Requestda)),14)
      ENDIF
      apr->(dbSkip())
   ENDDO

   apr->(dbClearFilter())
   
   ctext += "</pre>"
   IF lFound
      aTo := {}
      add(aTo,{"thimo.hamma@engelking.de","Thimo"})
      Aadd(aTo,{"amos.engelking@engelking.de","Amos","CC"})
      //SendMail(aTo,HB_AnsiToOem("Außstehende Genehmigungen"),cText,,,,.T.)
   ENDIF


   auf->(dbSetFilter({|| auf->Bestat >= 4 .AND. auf->BeStat <= 7}, "Bestat >= 4 .AND. BeStat < 7"))
   auf->(dbGoTop())

   lFound := .F.
   cText := "Folgende Auftr„ge warten auf eine Genehmigungsanfrage:<pre>"
   cText += "<br>Auftrag Benutzer"
   
   DO WHILE ! auf->(EOF())
      oAuftrag := Auftrag():New()
      oAuftrag:Load(auf->Abnr)

      lWaitApproval := .F.
      IsApproved("AUF",auf->Abnr,StoT(oAuftrag:LastChange),@lWaitApproval)
      IF ! lWaitApproval 
         cBuyer := Trim(Buy(auf->Buyer,.T.))
         cText += "<br><h1>"+Str(auf->Abnr,6)+" "+cBuyer+"</h1> "
         cText += GetNotesForEmail("AUF",auf->Abnr,.F.)
         lFound := .T.         
      ENDIF
      DO WHILE ! auf->(EOF()) .AND. auf->Abnr == oAuftrag:AbNr
         auf->(dbSkip())
      ENDDO      
   ENDDO

   IF lFound
      ctext += "</pre>"
      aTo := {}
      Aadd(aTo,{"amos.engelking@engelking.de","Amos"})
      SendMail(aTo,"Auftr„ge ohne Genehmigungsanfrage",cText,,,,.T.)
   ENDIF

