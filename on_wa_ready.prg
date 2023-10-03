FUNCTION HOOK_ON_WA_READY(nWaNr)
   LOCAL cMissing,oExtra,cText
   
   NetUse("engkund","ku")

   IF Right(Str(wer->End,4),2) == "99"
      RETURN .T. //send message
   ENDIF
   
   IF ! Empty(wer->Liefma)
      ku->(dbSeek( wer->Liefma+"L" ))

      oExtra := ku->(ExtraData():New(ku->Nummer))

      IF Date() >= AddWorkingDays(ku->St_Holiday,oExtra:ShipTime*-1) .AND. Date() <= AddWorkingDays(ku->En_Holiday,oExtra:ShipTime*-1) //will arrive in the suppliers holiday
         RETURN .F. //do nothing
      ENDIF

      IF oExtra:WaDay != 0 .AND. (DoW(Date()) != oExtra:WaDay .OR. Time() > "15:00:00")
         NetUse("lagerne","lne")
         lne->(dbSetOrder(8))
         lne->(dbSetFilter({|| lne->Kunde == wer->Liefma },"Kunde == wer->Liefma"))
         IF ! lne->(dbSeek( "0" )) //only if there is no other entnahme
            lne->(dbClearFilter())
            RETURN .F. //return false then this will not be processed any further
         ENDIF
         lne->(dbClearFilter())
      ENDIF

   ENDIF

   IF ! WAStart(nWaNr,,@cMissing)
      IF wer->Termin <= CWeek(Date()) .AND. (wer->RemindStat != "READY" .OR. wer->RemindDate+1 <= Date())  //Send Reminder if the WA is really due and once a day
         wer->(Rec_Lock(0))
         wer->RemindStat := "READY"
         wer->RemindDate := Date()
         wer->(dbUnLock())
         NetUse("artikel","art")
         art->(dbSetOrder(2))
         art->(dbSeek( Str(wer->Artno,6) ))
         cText := 'Auftrag: <a href="trader: -F WerkAuf('+LTrim(Str(nWaNr))+')">'+LTrim(Str(nWaNr))+"</a><br>"
         cText += 'Artikel: <a href="trader: -F BrowseArtikel('+"'"+Trim(art->Matchcode)+"'"+')">'+Trim(art->Matchcode)+"</a> (#"+LTrim(Str(art->Artikelnr))+")<br>"
         cText += "GrÅnde<br>"+StrTran(cMissing,Chr(13)+Chr(10),"<br>")
         SendMail(GetConfigEmail("PROD-READY"),t("WA "+LTrim(Str(nWaNr))+" konnte nicht ausgelˆst werden " ),cText,,,,.T.)
      ENDIF
      //RETURN .T.  //return .T. still sends email
   ENDIF
RETURN .F.