FUNCTION RUN_Heidelberger_LE
   LOCAL aData := {}
   LOCAL getlist := {}
   LOCAL nSt := 5
   LOCAL nR := nSt
   LOCAL nNr := 0
   LOCAL nAbruf := 0
   LOCAL nRahmen := 0
   LOCAL cPart  := Space(35)
   LOCAL cKunde := Pad("HEIDELBE",8)
   LOCAL dDate := CToD("")

   Head("Eingabe Bestelldaten")

   @ 01,00 SAY "Datum                " GET dDate VALID dDate <= Date()
   @ 02,00 SAY "Rahmenbestellung     " GET nRahmen PICTURE "9999999" VALID nRahmen != 0
   @ 02,00 SAY "Liefereinteilung Nr. " GET nNr PICTURE "9999999999" VALID nNr != 0
   @ 03,00 SAY "Abruf Nr.            " GET nAbruf PICTURE "999" VALID nAbruf != 0
   @ 04,00 SAY "Kundenartikelnummer  " GET cPart 
   @ 05,00 SAY "Liefereinteilung:"
   READ SAVE
   IF LastKey() == 27
      RETURN {}
   ENDIF


   DO WHILE LastKey() != 27
      Aadd(aData,{"QTY"=>0,"DATE"=>CToD("")})
      @ nR,00 SAY "Datum" GET aData[nR-nSt+1]["DATE"]
      @ nR,15 SAY "Menge" GET aData[nR-nSt+1]["QTY"]
      ReadModal(getlist,(nR-nSt)*2+4)   
      nR++
      IF Empty(ATail(aData)["DATE"])
         EXIT
      ENDIF
   ENDDO

   IF LastKey() == 27 .AND. (Len(aData) > 1 .OR. ! Empty(aData[1]["DATE"])) .AND. Tr_MsgBox("Verarbeiten?",,{"Ja","Nein"}) != 1
      RETURN {}
   ENDIF

   RETURN aData

