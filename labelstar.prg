PARAMETERS cFile,nCount,hFieldMap,cPrinter

#define LS_ET_SUCCESS 0
#define LS_ET_WARNING 1
#define LS_ET_ERROR   2
#define LS_DIR 'C:\Program Files (x86)\Carl Valentin GmbH\Labelstar Office\'

MEMVAR oLabelstar
LOCAL nX,cField
MEMVAR hLabels
PUBLIC hLabels,oLabelstar

//IF Tr_Getini(28) == 9 .AND. Tr_MsgBox("Alternative Druckmethode?",,{"Ja","Nein"}) == 1
   MBaseRun(Trim(Tr_Getini(1))+"\run\labelstar2",{cFile,nCount,hFieldMap,cPrinter})
   RETURN
//ENDIF

IF ValType(hFieldMap) != "H"
   hFieldMap := {=>}
ENDIF
IF ValType(nCount) != "N"
   nCount := 1
ENDIF

IF ValType(hLabels) != "H"
   hLabels := {=>}
ENDIF
IF ValType(oLabelstar) != "O"
   oLabelstar := CreateObject("LSOffice.Application")
   oLabelstar:Initialize()
   IF oLabelstar:HasError
      IF ! getConfigValue("BATCHMODE")
         Alert(oLabelstar:LastError:Message)
      ENDIF
      RETURN
   ENDIF
ENDIF

IF HHasKey(hLabels,cFile)
   oLabel := hLabels[cFile]["OBJ"]
ELSE
   oLabel := oLabelstar:OpenLabel(cFile)

   IF LabelStar_DisplayError(oLabelstar) .OR. oLabel == NIL
      RETURN
   ENDIF

   hLabels[cFile] := {"OBJ"=>oLabel,"FIELDS"=>{=>}}

   //read fields in
   nX := 0
   DO WHILE (oField := oLabel:GetFieldByIndex(nX)) != NIL
      //? oField:FieldName,":"
      hLabels[cFile]["FIELDS"][nX] := oField:GetContent()
      nX++
   ENDDO

ENDIF


cField := ""
FOR EACH cField IN hFieldMap
   oField := oLabel:GetFieldByName(cField:__eNumKey())

   IF oField != NIL
      oField:SetContent(cField)
   ENDIF
NEXT

//  CLS
FOR nX := 0 TO Len(hLabels[cFile]["FIELDS"])
    oField := oLabel:GetFieldByIndex(nX)
    BEGIN SEQUENCE WITH { |e| break(e) }
      cContent := &(hLabels[cFile]["FIELDS"][nX]) //hLabels[cFile]["FIELDS"][nX])
      oField:SetContent(cContent)
   RECOVER USING e

   END
   IF LastKey() == 27 //If there is a GetBox in the macro and the user has pressed ESC
      RETURN
   ENDIF
NEXT

IF cPrinter != NIL
   oLabel:ActivePrinter := cPrinter
//ELSEIF GetEnv("COMPUTERNAME") == "CAMEL"
//ELSEIF GetEnv("COMPUTERNAME") == "LEOPARD"
ELSE
   IF Type("Mini_StickPrint()") == "UI"
      oLabel:ActivePrinter := "CAB EOS4/300"
   ELSE
      oLabel:ActivePrinter := "Pica 108/12"
   ENDIF

   IF Tr_getini(28) == 9
      //oLabel:ActivePrinter := "Adobe PDF"
      //SInkey(0)
      //oLabel:ActivePrinter := "Buero"
   ENDIF

ENDIF

oLabel:Print(nCount)
LabelStar_DisplayError(oLabelstar)


IF oLabelstar:HasError
   Tr_MsgBox(oLabelstar:LastError:Message,"FEHLER")
ENDIF
//Inkey(0,128)

FUNCTION LabelStar_DisplayError(oLabelstar)
   LOCAL cTitle

   IF oLabelstar:LastError:ErrorType == LS_ET_SUCCESS
      RETURN .F.
   ENDIF
   IF ! GetConfigValue("BATCHMODE")
      cTitle := "Fehler"
      IF oLabelstar:LastError:ErrorType == LS_ET_WARNING
         cTitle := "Warnung"
      ENDIF
      Tr_MsgBox(oLabelstar:LastError:Message,cTitle)
   ENDIF
RETURN .T.