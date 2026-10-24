PROC ADD_TO_ARCHIVE()
   LOCAL getlist := {}
   LOCAL nNummer := 0
   LOCAL oAgorum,aFiles,aFilesAgorum,oObject
   LOCAL cDocType := "RE",dDate
   
   NetUse("englsre","re")
   

   oAgorum := AgorumCustomApi():New()
   
   Head("Rechnung zum Agorum Archiv hinzufgen")

   DO WHILE .T.

      @ 01,00 SAY "Rechnung" GET nNummer PICTURE "999999"
      READ
      IF LastKey() == 27
         RETURN
      ENDIF
      @ 02,00 CLEAR
      SetPos(2,0)
      re->(dbSetOrder(4))
      IF ! re->(dbSeek( Str(nNummer,6) ))
         ? "Rechnung nicht gefunden"    
         LOOP
      ENDIF
      oObject := Rechnung():New()
      oObject:Load(nNummer)

      aFiles := GetArchiveFiles( {cDocType=>nNummer} ) //this will only work if this does not return the files from Agorum which it does not do at the moment
      IF Len(aFiles) == 0
         ? "Rechnung nicht im Archiv gefunden"
         LOOP
      ENDIF
      ? ATail(aFiles)[6]
      aFilesAgorum := oAgorum:Search(cDocType,nNummer)
      ? ValToPrg(aFilesAgorum)
      IF Len(aFilesAgorum) != 0
         dDate := StoT(StrTran(StrTran(StrTran(ATail(aFilesAgorum)["date"],"-",""),"T",""),":",""))+2/24         
         IF dDate < ATail(aFiles)[3]
            ? "Dokument im Archiv ist „lter als das vorhandene - wird aktualisiert"
            ? StoD(ATail(aFilesAgorum)["date"])
         //oAgorum:UpdateInArchive(aFilesAgorum[1]["uuid"],aFiles[6])
         ELSE
            ? "Dokument im Archiv ist aktueller (oder gleich) als das vorhandene - wird nicht aktualisiert"
            ? dDate,ATail(aFiles)[3]
         ENDIF
      
      ELSE
         ? "Dokument nicht im Agorum Archiv gefunden - wird hinzugefgt"
         IF ! oAgorum:AddFile(cDocType,ATail(aFiles)[6],oObject)
            ? "Fehler beim Hinzufgen: ",oAgorum:cErrorText
         ELSE
            ? "Dokument erfolgreich hinzugefgt"
         ENDIF
      ENDIF
   ENDDO
   

   