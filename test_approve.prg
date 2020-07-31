LOCAL aApro,nUSer

IF ProcName(9) == "BROWSEAUF"
   oAuftrag := Auftrag():New(.F.)
   oAuftrag:Load(auf->Abnr)
   aApro := Hook("approve_auftrag",{oAuftrag})
ELSEIF ProcName(8) == "ENQFO"
   aApro := Hook("approve_angebot",{ang->Angnr})
ENDIF

IF aApro != NIL
   IF ! Empty(aApro[1])
     cText := aApro[1]
     cText += ";Genehmigung muss erfolgen durch:;"
     FOR EACH nUser IN aApro[2]
        cText += Buy(nUser,.T.)+";"
     NEXT
     Alert(cText)
   ELSE
      Alert("OK")
   ENDIF
ENDIF
