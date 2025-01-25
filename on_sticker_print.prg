FUNC HOOK_ON_STICKER_PRINT(cName,nCount )

LOCAL cEtiPath := "\\EK-SERVER4\DATA\Dokumente und Einstellungen\All Users\Dokumente\Aufkleber\Allgemein\"
LOCAL cFile    

cFile    := cEtiPath+cName+".lbex"
IF File(cFile)
   IF Tr_GetIni(28) == 9
      Alert("PRINTING "+cFile)
   ENDIF
   MBaseRun(Trim(Tr_getini(1))+"\run\labelstar",{cFile,nCount})
   RETURN .F.
ELSE
   Alert("NO FILE FOUND "+cFile)
ENDIF

RETURN .T.