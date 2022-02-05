#define NL Chr(13)+Chr(10)
#define LS_OUT_PATH '\\EK-SERVER4\Data\Labelstar\'
#define LS_OUT_LOCAL 'C:\Valentin\Monitor\'
#define COMPUTERNAME 'EK-SERVER1'


PROC RUN_LABELSTAR( cFile,nCount,hFieldMap,cPrinter )


MEMVAR oLabelstar
LOCAL nX,cField
LOCAL cPath,cFileName
LOCAL cOutFile,nH
LOCAL cChar
LOCAL cAdd
LOCAL cString

IF ValType(hFieldMap) != "H"
   hFieldMap := {=>}
ENDIF
IF ValType(nCount) != "N"
   nCount := 1
ENDIF

HB_FNameSplit( cFile, @cPath, @cFileName )

IF File(cPath+cFileName+".prg")
   hFieldMap := MBaseRun(cPath+cFileName+".prg",{hFieldMap})
ENDIF

IF .F. //GetEnv("COMPUTERNAME") == COMPUTERNAME .AND. Tr_Getini(28) == 9
   cOutFile := LS_OUT_LOCAL
ELSE
   cOutFile := LS_OUT_PATH
ENDIF
cOutFile += Trim(Tr_Getini(20))+"_"+DtoS(Date())+StrTran(Time(),":","")

nX := 0
cAdd := ""
DO WHILE File(cOutFile+cAdd+".xml")
   nX++
   cAdd := "_"+LTrim(str(nX))
ENDDO
cOutFile += cAdd+".xml"

nH := FCreate(cOutFile)

//IF Tr_Getini(28) == 9; Alert("File created"); ENDIF

IF nH <= 0
   Tr_MsgBox("Create error")
   RETURN
ENDIF

FWrite(nH,'<?xml version="1.0" encoding="utf-8"?>'+NL)
FWrite(nH,'<LSO version="1.0">'+NL)
FWrite(nH,'<layout>'+cFile+'</layout>'+NL)

cField := ""
FOR EACH cField IN hFieldMap
   cString := hb_strtoutf8(cField)
   FOR EACH cChar IN {"&"=>"&amp;","<"=>"&lt;",">"=>"&gt;"}
      cString := StrTran(cString,cChar:__eNumKey(),cChar)
   NEXT
   FWrite(nH,'<field name="'+cField:__eNumKey()+'">'+cString+'</field>'+NL)
NEXT

IF cPrinter == NIL
   IF Type("Mini_StickPrint()") == "UI"
      cPrinter := "CAB EOS4/300"
   ELSE
      cPrinter := "Pica 108/12"
   ENDIF

   IF Tr_getini(28) == 9
      //cPrinter := "Amos"
      //SInkey(0)
      //oLabel:ActivePrinter := "Buero"
   ENDIF

ENDIF
FWrite(nH,'<printer>'+cPrinter+'</printer>'+NL)
FWrite(nH,'<copies>'+LTrim(Str(nCount))+'</copies>'+NL)
FWrite(nH,'</LSO>')

FClose(nH)