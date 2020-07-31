LOCAL getlist := {}
LOCAL nMonth  := Month(Date())
LOCAL nYear   := Year(Date())
LOCAL cFile   := ""
LOCAL lDummy  := .F.,cErr

DO WHILE .T.
   Head("IDEV Upload of Intrastat file")
   
   @ 01,00 SAY "Monat" GET nMonth PICTURE "99"
   @ 02,00 SAY "Jahr " GET nYear  PICTURE "9999"
   @ 03,00 GET lDummy PUSHBUTTON CAPTION t("Datei auswählen") STATE {|| 
      cFile := Wvt_GetOpenFileName( 0,"" , "PRG Datei", { {"Alle Dateien (*.*)","*.*"} }, , Trim(Tr_Getini(1))+"\export\intrastat\" )
      IF Len(cFile) > MaxCol()-18
         @ 03,18 SAY "..."+Right(cFile,MaxCol()-15)
      ELSE
         @ 03,18 SAY cFile
      ENDIF
   }
   @ 04,00 GET lDummy PUSHBUTTON CAPTION t("ausführen") STATE {||
      IF Empty(cFile)
         Alert(t("Bitte Datei auswählen"))
         RETURN .T.
      ENDIF
      IF ! CallIdev("upload",'-firma _MELDER_ -stid 53 -land 00 -bzr '+Str(nYear,4)+' -p monat='+StrZero(nMonth,2)+' -d datei="'+cFile+'"',,@cErr)
         Alert(cErr)
      ELSE
         Alert("Erfolgreich")
      ENDIF
   }
   READ

   IF LastKey() == 27
      EXIT
   ENDIF
ENDDO