PROC CHECK_FRAME_PO
   LOCAL nWeek := AddWeeks(CWeek(Date()),8)
   LOCAL nBesnr
   LOCAL aTo := {{"amos.engelking@engelking.de","Amos"},{"daniel.becker@engelking.de","Daniel"}}
   LOCAL cMessage,cSubject

   NetUse("engbes","bes")

   bes->(dbSetFilter( {|| bes->Rahmen .AND. bes->beqty > 0 .AND. (bes->lterm < nWeek .OR. bes->wterm < nWeek) } ,"rahmen .AND. beqty > 0 .AND. (lterm < "+LTrim(Str(nWeek))+" .OR. wterm < "+LTrim(Str(nWeek))+")" ))
   bes->(dbSetOrder( 10 ))
   bes->(dbGoTop())

   DO WHILE bes->Bestat < 3
      cSubject := "Rahmenbestellung "+LTrim(Str(bes->Besnr))+" l„uft aus/ist ausgelaufen:"
      ? bes->Besnr,bes->BeQty,bes->Lterm,bes->Wterm,bes->Rahmen
      nBesnr := bes->Besnr
      cMessage := "Folgende Positionen laufen bald aus: <br><pre>"
      cMessage += Pad("Artikel",25)+" "+Pad("Menge",12)+" Woche<br>"
      DO WHILE bes->Besnr == nBesnr .AND. bes->Bestat < 3 .AND. ! bes->(EOF())
         oArt := Artikel():New()
         oArt:Load(bes->Artikelnr)
         cMessage += oArt:Matchcode+" "+Pad(Transform(bes->BeQty,oArt:cPicture),12)+" "+NiceWeek(Min(bes->Lterm,bes->Wterm))+"<br>"
         bes->(dbSkip())
      ENDDO
      cMessage += "</pre>"
      SendMail(aTo,cSubject,cMessage)
   ENDDO

   