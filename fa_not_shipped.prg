PROC FA_NOTSHIPPED
   LOCAL cWeek := CalWeek(Date())
   LOCAL cFilter := 'status == 0 .AND. termin <= '+cWeek
   LOCAL cLiefma,cText
   
   NetUse("werkauf","wer")
   NetUSe("artikel","art")
   art->(dbSetOrder( 2 ))

   wer->(dbSetOrder( 7 ))
   wer->(dbSetFilter({|| wer->(&(cFilter))},cFilter))

   CLS
   
   FOR EACH cLiefma IN {Pad("WHTECH",8)}
      wer->(dbSeek( cLiefma ))
      ? cLiefma
      cText := "Hallo,<br><br>das Beistellmaterial fÅr folgende FertigungsauftrÑge wurde nicht an "+Trim(cLiefma)+" versandt:<br><pre>"
      cText += "Auf.Nr "+Pad("Artikel",25)+" "+PadL("Menge",12)+" Woche"
      
      DO WHILE ! wer->(EOF()) .AND. wer->Liefma == cLiefma
         art->(dbSeek( Str(wer->Artno,6) ))
         cText += "<br>"+Str(wer->Aufno,6)+" "+art->Matchcode+" "+PadL(Transform(wer->Qty,Me(art->me)),12)+" "+NiceWeek(wer->Termin)
         wer->(dbSkip())
      ENDDO
      SendMail({{"daniel.becker@engelking.de","Daniel"},{"amos.engelking@engelking.de","Amos"}},"FertigungsauftrÑge fÅr "+Trim(cLiefma),cText,,,,.T.)
   NEXT

//   Sinkey(0)
