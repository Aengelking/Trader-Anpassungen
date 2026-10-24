PROC RUN_DAVID_Attachments
   LOCAL oAccount,oArchive,oEntries,oEntry,nItm,nAtt,cFileName,oAtt
   LOCAL cArchive := "\\EK-SERVER3\DAVID\archive\user\10004000\system\found"  //meine Suchergebnisse
   LOCAL cToPath := "Y:\Dokumente und Einstellungen\All Users\Dokumente\Lieferanten\Signal\Zeichnungen"
   LOCAL cToFile
   
   oAccount := DV_GetMailAccount()
   
   oArchive := oAccount:GetArchive(cArchive)
   oEntries := oArchive:MailItems() //GetArchiveEntries()

   ? oEntries:Count, "Eintr„ge gefunden"
   ?
   FOR nItm := 0 TO oEntries:Count-1
      @ Row(),00 SAY nItm
      oEntry := oEntries:Item(nItm)
      //? oEntry:Subject
      FOR nAtt := 0 TO oEntry:Attachments:Count-1
         oAtt := oEntry:Attachments:Item(nAtt)
         cFileName := Upper(oAtt:FileName)
         IF (AT("SGNY",cFileName) > 0 .OR. AT("SGNW",cFileName) > 0) .AND. AT("PDF",cFileName) > 0
            ? oEntry:Attachments:Item(nAtt):FileName            
            cToFile := StrTran(oAtt:FileName,"?","_")
            IF ! File(cToPath+"\"+cToFile)               
               oAtt:CopyOut(cToPath,cToFile) 
            ELSE
               ?? " Datei existiert bereits"
            ENDIF
            ?
         ENDIF         
      NEXT
   NEXT
   Sinkey(0)