LOCAL cPath := "Y:\Archive\Rechnungen\"

LOCAL cData := "",cLine
LOCAL cFile
LOCAL nPDF
LOCAL nTotal

LOCAL nRechnr := 34169 //47138

NetUse("skontoa","sk")
NetUse("englsre","re")
re->(dbSetOrder( 8 ))


Head(t("Rechnungssummen prüfen"))
@ 01,00 SAY "Ab Rechnungsnr." GET nRechnr VALID nRechnr >= 34169 PICTURE "999999"
READ

IF LastKey() == 27
   RETURN
ENDIF

re->(dbSeek(Str(0,3)+Str(nRechnr,6)))


DO WHILE re->RePosnr == 0 .AND. ! re->(EOF())
   IF re->Packed
      aDir := Directory(cPath+"RE"+StrZero(re->Rechnr,6)+"*.pdf")
      IF Len(aDir) == 0
   //      ? re->Rechnr,"keine Datei gefunden"
         nPdf := -3
      ELSE
         cFile := cPath+ATail(aDir)[1] //cPath+"RE"+StrZero(re->Rechnr,6)+".pdf"
   
         cData := MemoRead(cFile)
         IF Empty(cData)
            //? re->Rechnr,"Datei nicht gefunden"
            nPdf := -2
         ELSE
            aRegex := HB_Regex("\((EUR|GBP)\s*([\-0-9\.]{1,})\)",cData)
            IF Len(aRegex) == 0
               nPDF := -1
               //MemoEdit(cData)
               //? re->Rechnr,"Summe nicht gefunden"
            ELSE
               IF aRegex[2] != "EUR"
                  ? re->Rechnr,re->Rechdat,t("Falsche Währung")
               ENDIF

               nPDF := Val(aRegex[3])
            ENDIF
         ENDIF
      ENDIF
      nTotal := Round(GetRechnungSumme(),2)
   
      IF nPDF == re->PosWt .AND. nPDF == nTotal
        //@ Row(),Col()+1 SAY "OK" COLOR "G/W"
      ELSEIF nTotal != 0
         ? re->Rechnr,re->Rechdat,"PDF: "+IF(nPdf==-1,"Keine Summe "+cFile,IF(nPdf==-2,"Datei leer",IF(nPDf==-3,"Keine Datei",LTrim(Str(nPDF)))))+" Trader: "+LTrim(Str(re->PosWt))+" Added up: "+LTrim(Str(nTotal))
      ENDIF
   ENDIF

   re->(dbSkip())
ENDDO

? "Done"

SInkey(0)

STATIC FUNCTION GetRechnungSumme()
   Local aEnv := SaveEnv()
   LOCAL nRechnr := re->Rechnr
   LOCAL nTotal := 0
   LOCAL nMwstRate := 0
   LOCAL nMwst

   re->(dbSetOrder( 12 ))
   re->(dbSeek( Str(nRechnr,6)+Str(0,3) ))
   nTotal := re->OfQty //Porto
   IF re->reart <  2 //netto, dann muss die MwSt Rate gesetzt werden, ansonsten bleibt diese bei 0
      taxit( re->taxcode,@nMwStRate,re->rechdat,.F. )
   ENDIF
   re->(dbSkip( 1 ))
   DO WHILE ! re->(EOF()) .AND. re->RECHNR == nRechnr
      If re->reposnr != 0
         nTotal += ROUND( (re->aoqty*re->preis/re->pe)*(1-re->rabatt/100),2)+re->Zuschlag
      Endif
      re->(dbSkip())
   ENDDO

   nMwSt := Int( nTotal*nMwStRate+If(nTotal>=0,0.5,-0.5) )/100.00
   nTotal := nTotal+nMwSt

   RestEnv(aEnv)
RETURN nTotal
