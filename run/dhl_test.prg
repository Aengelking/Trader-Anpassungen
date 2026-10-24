LOCAL oDHL := I_DHL() //:New()

//MBaseRun(Trim(Tr_Getini(1))+"\interfaces\dhl.prg")
/****************
   Sendungsnummern für den Test sind unter
   https://entwickler.dhl.de/en/group/ep/foren/-/message_boards/message/232243
   zu finden
*****************/
//Alert(oDHL:getStatusForPublicUser("00340434161094042557")) <-- This does not work!
oXML := oDHL:getPiece("00340434161094042557") //;00340434161094038253;00340434161094032954;00340434161094027318;00340434161094022115;00340434161094015902")
nSec := Seconds()
IF oXML != NIL
   MemoEdit(oXML:oRoot:toString(1))
   oIter := TXMLIteratorScan():New(oXml:oRoot)
   oData := oIter:Find("data","name","piece-shipment")
   DO WHILE oData != NIL
      cID := oData:getAttribute("piece-id")
      Alert("Found "+cID+" "+IF(oData:getAttribute("delivery-event-flag")=="1","","noch nicht ")+"geliefert")
      DO WHILE Seconds()-nSec < 10
         ? Seconds()-nSec
         Inkey(1)
      ENDDO
      oXML := oDHL:getPieceEvents("00340434161094042557",cId)
      IF oXML != NIL
         MemoEdit(oXML:oRoot:toString(1))
      ELSE
         DHL_errorMsg(oDHL)
      ENDIF
      oData := oIter:Next()
   ENDDO
ELSE
   DHL_errorMsg(oDHL)
ENDIF



Function DHL_errorMsg(oDHL)
   IF oDHL:nLastError == 1
      Alert("Verbindungsfehler")
   ELSEIF oDHL:nLastError == 2
      Alert("Service im Wartungsmodus")
   ELSEIF oDHL:nLastError == 3
      Alert("Fehler in den Daten;"+oDHL:cData)
   ELSE
      Alert("unbekannter Fehler")
   ENDIF
RETURN NIL

#include "X:\interfaces\dhl.prg"
