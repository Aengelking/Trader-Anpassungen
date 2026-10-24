//#define DvArchiveRoot	 	0
//#define DvArchivePersonalIn	101
//#include "hbdyn.ch"

#include "y:\harbour\trader\source\include\david.ch"
#include "y:\hb32\include\dll.ch"
PROC RUN_DAVID_ARCHIVE

MEMVAR mnhDll

LOCAL oAccount := DV_GetMailAccount()
LOCAL oUsers := oAccount:GetSpecialArchive(DvArchiveUserRoot):Archives
LOCAL oArchive  := oAccount:GetSpecialArchive(DvArchivePersonalOut)
//LOCAL cDir := "\\EK-SERVER4\data\Dokumente und Einstellungen\amos\Eigene Dateien\TestArchive\"
//LOCAL cDir := "Y:\Dokumente und Einstellungen\amos\Documents\TestArchive\"
LOCAL cDir := "Y:\Dokumente und Einstellungen\administrator\Documents\TestArchive\"
//LOCAL cDir := "E:\EmailTestArchive\"


LOCAL nExported,nSkipped,nFailed

IF Right(cDir,1) $ "\\/"
ELSE
   cDir += "\\"
ENDIF

nExported := 0
nSkipped := 0
nFailed := 0

/*FOR nX := 0 TO oUsers:Count-1
   ? "Benutzer:", oUsers:Item(nX):DisplayName
   //oArchive := oUsers:Item(nX):GetArchiveEntryById(oUsers:Item(nX):ID+"\out")
   oArchive := oAccount:ArchiveFromId(oUsers:Item(nX):ID+"\out")
   
   _Recurse(oAccount,oArchive,cDir,@nExported,@nSkipped,@nFailed)
NEXT*/


_Recurse(oAccount,oArchive,cDir,@nExported,@nSkipped,@nFailed)

? "Export beendet."
? "Exportiert:", nExported
? "šbersprungen:", nSkipped
? "Fehlgeschlagen:", nFailed
? "Ziel:", cDir


Inkey(0,128)
Sinkey(0)
RETURN

STATIC FUNCTION _Recurse(oAccount,oArchive,cDir,nExported,nSkipped,nFailed)
   LOCAL oItems := oArchive:AllItems
   LOCAL nX,oItem
   LOCAL cFile,cEnd,cTarget
   LOCAL nFormat
   LOCAL oConverter,oCollection
   LOCAL lDone
   LOCAL cChars
   LOCAL nCur,nTotal
   LOCAL tSend
   LOCAL nSub
   LOCAL aMessageIDs := {}

   LOCAL tLastExport := StoT("202603201800") //only export items up to this date to avoid exporting too much data during testing

   ? oArchive:ID

   FOR nX := 0 To oItems:Count-1
	   oItem := oItems:Item(nX)

      //Create File Name

      cFile := ""
      cEnd := ""
      nFormat := 0

      tSend := oItem:Fields:Item("StatusTime"):Value

      IF tSend <= tLastExport
         ? "Letzter Export erreicht, Export wird abgebrochen. Letztes Datum:", TtoC(tSend)
         EXIT      
      ENDIF

      IF ASCan(aMessageIDs,oItem:Fields:Item("JobID"):Value) != 0
         //? "Nachricht bereits exportiert, wird bersprungen:",oItem:Subject
         nSkipped++
         LOOP
      ENDIF
      
      Aadd(aMessageIDs,oItem:Fields:Item("JobID"):Value)

      IF AT("AUTOREPLY",oItem:Subject) == 1
         ? "Ignoriert - Autoreply:", oItem:Subject
         nSkipped++
         LOOP
      ENDIF

	   IF oItem:Type == DvFaxItem
         cFile := oItem:Fields:Item("SRFrom"):Value
         cEnd := "fax"
         nFormat := 2
	   ELSEIF oItem:Type == DvEMailItem
         IF _IsInternalRecipientsOnly(oItem)
            nSkipped++
            ? "Ignoriert (nur intern):", oItem:Subject
            LOOP
         ENDIF

         cFile := oItem:Subject
         cEnd := "eml"
         nFormat := 5
		ENDIF

      IF Empty(cFile)
         cFile := "Item"
      ENDIF

      IF Empty(cEnd) .OR. nFormat == 0
         nSkipped++
         LOOP
      ENDIF

		cFile += "_"+TtoS(oItem:Fields:Item("StatusTime"):Value)

      cChars := "\*/"
      cFile := CharRepl(cChars,cFile,Replicate("_",Len(cChars)))
      cChars := ':?-"<>|-'
      cFile := CharRepl(cChars,cFile,Space(Len(cChars)))
      cFile := AllTrim(cFile)
      cFile := StrTran(cFile,Chr(9)," ") 

      cFile := StrTran(cFile," ","_")  //the file exporter does not like spaces in file names

      cFile += "."+cEnd
      cTarget := cDir+cFile
      
      IF File(cTarget)
         ? "šbersprungen Datei bereits vorhanden:",cTarget
         nSkipped++
         LOOP
      ENDIF

      
      oConverter := oAccount:CreateExporter()
      oConverter:SetAsyncMode(.F.)
      oCollection := oConverter:GetCollection()

      oCollection:Add(oItem)
      oConverter:Convert(nFormat,cTarget)
      nCur := 0
      nTotal := 0
      
      oConverter:GetProgress(@nCur,@nTotal)
      lDone := nCur >= nTotal .AND. nTotal > 0

      IF lDone         
         IF !_SetFileDateTime(cTarget,tSend)
            ? "Hinweis: Zeitstempel nicht gesetzt:", cTarget
         ENDIF
      ENDIF

      IF lDone
         nExported++
         ? "Exportiert:", cTarget
      ELSE
         nFailed++
         ? "Fehler beim Export:", cTarget,nCur,nTotal
      ENDIF
	NEXT

   
   FOR nSub := 0 TO oArchive:Archives:Count-1
     // _Recurse(oAccount,oArchive:Archives:Item(nSub),cDir,@nExported,@nSkipped)
   NEXT
   

RETURN NIL

STATIC FUNCTION _IsInternalRecipientsOnly(oItem)
   LOCAL cTo
   LOCAL cCc
   LOCAL cBcc
   LOCAL cAll
   LOCAL aParts
   LOCAL cPart
   LOCAL cDomain
   LOCAL lHasRecipients := .F.

   cTo := _GetFieldValue(oItem,"To")
   cCc := _GetFieldValue(oItem,"Cc")
   cBcc := _GetFieldValue(oItem,"Bcc")

   cAll := cTo+";"+cCc+";"+cBcc
   cAll := StrTran(cAll,Chr(13),";")
   cAll := StrTran(cAll,Chr(10),";")
   cAll := StrTran(cAll,",",";")

   aParts := HB_ATokens(cAll,";")
   FOR EACH cPart IN aParts
      cDomain := _ExtractRecipientDomain(cPart)
      IF ! Empty(cDomain)
         lHasRecipients := .T.
         IF ! _IsInternalDomain(cDomain)
            RETURN .F.
         ENDIF
      ENDIF
   NEXT

RETURN lHasRecipients

STATIC FUNCTION _GetFieldValue(oItem,cField)
   LOCAL cValue

   BEGIN SEQUENCE
      cValue := oItem:Fields:Item(cField):Value
      IF ValType(cValue) != "C"
         cValue := hb_ValToStr(cValue)
      ENDIF
   RECOVER
      cValue := ""
   END SEQUENCE

RETURN cValue

STATIC FUNCTION _ExtractRecipientDomain(cToken)
   LOCAL cValue := Lower(AllTrim(cToken))
   LOCAL nAt,nX
   LOCAL cDomain := ""
   LOCAL cChar

   IF Empty(cValue)
      RETURN ""
   ENDIF

   IF "<" $ cValue .AND. ">" $ cValue
      cValue := SubStr(cValue,At("<",cValue)+1,Rat(">",cValue)-At("<",cValue)-1)
      cValue := AllTrim(cValue)
   ENDIF

   nAt := Rat("@",cValue)
   IF nAt == 0
      RETURN ""
   ENDIF

   cValue := SubStr(cValue,nAt+1)

   FOR nX := 1 TO Len(cValue)
      cChar := SubStr(cValue,nX,1)
      IF cChar $ "abcdefghijklmnopqrstuvwxyz0123456789.-"
         cDomain += cChar
      ELSE
         EXIT
      ENDIF
   NEXT

RETURN cDomain

STATIC FUNCTION _IsInternalDomain(cDomain)
   LOCAL cCheck := Lower(AllTrim(cDomain))

RETURN cCheck == "engelking.de" .OR. ;
       cCheck == "engelking.eu" .OR. ;
       cCheck == "engelking.com" .OR. ;
       cCheck == "bcc.nocrm.io" .OR. ;
       cCheck == "engelking.it" 

STATIC FUNCTION _SetFileDateTime(cFile,tStamp)
   LOCAL cStamp
   LOCAL dDate
   LOCAL cTime

   IF Empty(cFile) .OR. ! File(cFile)
      RETURN .F.
   ENDIF

   IF ValType(tStamp) != "T"
      RETURN .F.
   ENDIF

   cStamp := TtoS(tStamp)
   IF Len(cStamp) < 14
      RETURN .F.
   ENDIF

   dDate := SToD(Left(cStamp,8))
   cTime := SubStr(cStamp,9,2)+":"+SubStr(cStamp,11,2)+":"+SubStr(cStamp,13,2)

RETURN SetFDaTi(cFile,dDate,cTime)




