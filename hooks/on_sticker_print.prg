FUNC HOOK_ON_STICKER_PRINT(cName,nCount,hFieldMap )

LOCAL cEtiPath := "\\EK-SERVER4\DATA\Dokumente und Einstellungen\All Users\Dokumente\Aufkleber\Allgemein\"
LOCAL cFile    

//Vierter Parameter ist optional - StickPrint reicht ihn nur durch, wenn der
//Aufrufer Felder mitgibt (z.B. die QM-Pruefnummer beim Wareneingang).
IF ValType(hFieldMap) != "H"
   hFieldMap := {=>}
ENDIF

cFile    := cEtiPath+cName+".lbex"
IF File(cFile)
   IF Tr_GetIni(28) == 9
      //Alert("PRINTING "+cFile)
   ENDIF
   MBaseRun(Trim(Tr_getini(1))+"\run\labelstar",{cFile,nCount,hFieldMap})
   IF Upper(cName) == "WARE" .AND. Select("art") != 0 .AND. Left(art->Matchcode,2) == "NZ" .AND. art->Manufactur == 9 
      IF Tr_GetIni(28) == 9
         //Alert("PRINTING GPSR Label")
      ENDIF
      MBaseRun(Trim(Tr_getini(1))+"\run\labelstar",{cEtiPath+"GPSR_scolmore.lbex",nCount,hFieldMap})
   ENDIF
   RETURN .F.
ELSE
   //Alert("NO FILE FOUND "+cFile)
ENDIF

RETURN .T.