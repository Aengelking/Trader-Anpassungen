PROC RUN_EDIT_EXTRAFIELDS(cAli,lNr)
   LOCAL cFile,oBrowse,cName,nOrd
   LOCAL getlist := {},nNr := 0
   MEMVAR c_one
   Default(@lNr,.F.)
   //SetColor(c_four)
   IF Upper(cAli) == "REH"
      cFile := "rechnung"
      cName := "Rechnung"
      nOrd  := 1
   ELSEIF Upper(cAli) == "ANG"
      cFile := "angebot"
      cName := "Angebot"
      nOrd  := 1
   ELSEIF Upper(cAli) == "BES"
      cFile := "engbes"
      cName := "Bestellung"
      nOrd  := 1
   ELSEIF Upper(cAli) == "KU"
      cFile := "engkund"
      cName := "Adressen"
      nOrd  := 1
      
   ENDIF
   IF Empty(cFile)
      RETURN
   ENDIF  
   Head("Extrafelder fr "+cName+" bearbeiten")

   NetUSe(cFile,cAli)
   (cAli)->(dbSetOrder(1))

   IF lNr
      DO WHILE .T.
         @ 01,00 SAY "Nummer" GET nNr PICTURE "999999" 
         READ
         IF LastKey() == 27
            RETURN
         ENDIF
         @ 01,14 CLEAR TO 01,30
         IF ! (cAli)->(dbSeek( Str(nNr,6) ))
            @ 01,14 SAY "NICHT GEFUNDEN"
         ELSE            
            EXIT
         ENDIF
      ENDDO
   ENDIF
   
   oBrowse := (cAli)->(ExtraDataBrowse(nNr,IF(lNr,3,2),0,MaxRow(),MaxCol(),!lNr))
   oBrowse:ColorSpec := "N/W,N+/BG,N+/BG,N/BG,G/B"
   oBrowse:EventLoop()
RETURN
