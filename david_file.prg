PROCEDURE RUN_DAVID_FILE
   LOCAL nNr := 0,nPrinter := 0
   LOCAL getlist := {},nX,aFiles
   
   LOCAL oPrinter := Printer()
   LOCAL nChoice
   LOCAL aTypes := {"AB","TA","PI","ANG","RE","BES"},nType   
   LOCAL aMenu := {"Auftragsbest„tigung","Termin„nderung","Proforma Rechnung","Angebot","Rechnung","Bestellung"}
   LOCAL cKunde
   
   nType := AMenu(aMenu) //"Anfrage","Bestellung"})
   IF nType == 0
      gtSetClipboard("")
      RETURN
   ENDIF

   FOR nX := 1 TO Len(oPrinter:Printers)
      IF Trim(oPrinter:Printers[nX,2]) == "Create PDF"
         nPrinter := nX
         EXIT
      ENDIF
   NEXT
   IF nPrinter = 0
      FOR nX := 1 TO Len(oPrinter:Printers)
         IF Trim(oPrinter:Printers[nX,2]) == "PDF"
            nPrinter := nX
         ENDIF
      NEXT
   ENDIF

   SetConfigValue("printer",nPrinter)
   Head(aMenu[nType]+" anh„ngen")
   @ 01,00 SAY "Nummer" GET nNr VALID nNr != 0 PICTURE "999999"
   READ
   
   IF LastKey() == 27
      gtSetClipboard("")
      RETURN 
   ENDIF
   NetUSe("engkund","ku")

   
   SWITCH nType
      CASE 1
      CASE 2
      CASE 3
         NetUse("engauf","auf")
         auf->( dbSetOrder( 1 ) )
         IF auf->( dbSeek( Str( nNr, 6 ) ) )
            cKunde := auf->KundMa
         ENDIF
         EXIT
      CASE 4
         NetUse("angebot","ang")
         ang->(dbSetOrder( 1 ))
         IF ang->(dbSeek( Str(nNr,6) ))
            cKunde := ang->Kundma
         ENDIF
         EXIT
      CASE 5         
         NetUse("englsre","re")
         re->(dbSetOrder( 4 ))         
         IF re->(dbSeek( Str(nNr,6) ))    
            IF ! re->Packed
               Tr_MsgBox("Rechnung ist noch nicht gepackt - kann daher nicht angeh„ngt werden")        
               RETURN
            ENDIF
            cKunde := re->Kunde
         ENDIF
         EXIT
      CASE 6
         NetUse("engbes","bes")
         bes->(dbSetOrder( 1 ))
         IF bes->(dbSeek( Str(nNr,6) ))
            cKunde := bes->Liefma
         ENDIF
         EXIT   
   ENDSWITCH


   IF ! Empty(cKunde)
      Findad( cKunde, "K", 01, 40 )

      DO WHILE .T.         
         aFiles := GetArchiveFiles( {aTypes[nType]=>nNr} )
         
         IF Len(aFiles) == 0
            nChoice := Tr_MsgBox("Keine Dateien vorhanden",,{"erstellen","abbrechen"})+2        
         ELSE
            nChoice := Tr_MsgBox("Dokument vom "+DToC(ATail(aFiles)[3])+" "+ATail(aFiles)[4]+" anh„ngen?",,{"Ja","Nein","neu erstellen","abbrechen"}) 
         ENDIF
         IF nChoice == 1
            gtSetClipboard(ATail(aFiles)[6])
            EXIT
         ELSEIF nChoice == 3
            IF nPrinter == 0
               Tr_MsgBox("Kein Drucker 'Create PDF' gefunden")
               LOOP               
            ENDIF
            SetConfigValue("batchmode",.T.)
            SWITCH nType
               CASE 1
               CASE 2
               CASE 3            
                  enabdr( nNr, nType-1)
                  EXIT
               CASE 4
                  enqdr(nNr,.F.)             
                  EXIT  
               CASE 5
                  engrepr("",1,nNr,.F.,1,0)
                  //Tr_MsgBox("Rechnung kann nicht neu erstellt werden")
                  EXIT
               CASE 6
                  enbedr(nNr)
                  EXIT
            ENDSWITCH
            SetConfigValue("batchmode",.F.)
         ELSEIF nChoice == 4            
            gtSetClipboard("")
            EXIT
         ENDIF
      ENDDO
   ENDIF
RETURN 