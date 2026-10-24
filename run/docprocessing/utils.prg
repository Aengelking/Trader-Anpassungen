STATIC FUNCTION StandardiseValue(cVal,cType)
   LOCAL cRepl,hReplace := {" UND "=>"&"," AND "=>"&","+"=>"&","."=>"","/"=>"","-"=>"",":"=>""}
   Default(@cType,"")
   IF cType == "name"
      hReplace := HB_HCopy({"AKTIENGESELLSCHAFT"=>"AG","LIMITED"=>"LTD"},hReplace)
   ELSEIF cType == "address"
      hReplace := HB_HCopy({"STRASSE"=>"STR","STREET"=>"ST","STRADA"=>"STR"," NR "=>""},hReplace)
   ENDIF
   FOR EACH cRepl IN hReplace
      cVal := StrTran(cVal,cRepl:__eNumKey(),cRepl)
   NEXT
   cVal := StrTran(cVal," ","")
RETURN cVal

STATIC FUNCTION CompareValue(cVal,cVal2,cType)
   LOCAL aTokens,aTokens2
   cVal := DeUpper(cVal)
   cVal2 := DeUpper(cVal2)
   Default(@cType,"")
   IF cType == "city"
      aTokens := HB_ATokens(cVal," ")
      aTokens2 := HB_ATokens(cVal2," ")
      RETURN aTokens[1] $ cVal2 .OR. aTokens2[1] $ cVal
   ELSE
      cVal := StandardiseValue(cVal,cType)
      cVal2 := StandardiseValue(cVal2,cType)
   ENDIF
RETURN cVal == cVal2

STATIC FUNCTION Error(cError)
   MEMVAR c_one
   SetColor("R+/W*")
   ? cError
   SetColor(c_one)
RETURN NIL



STATIC FUNCTION CorrectPartNoErrors(cVal)
   LOCAL hSearchReplace := {"CM1([0-9]{2})/(.*)"=>"CMI$1/$2","C1([0-9]{2})/(.*)"=>"CI$1/$2"}
   LOCAL cRepl,cRegex
   LOCAL nStart,nLen,nMatch,aMatches
   //Remove any blank characters
   cVal := StrTran(cVal," ","")
   //Errors often come from OCR
   FOR EACH cRepl IN hSearchReplace
      cRegex := cRepl:__eNumKey()
      aMatches := HB_Regex(cRegex,cVal,@nStart,@nLen)
      IF Len(aMatches) != 0
         cVal := cRepl
         FOR nMatch := 1 TO Len(aMatches)
            cVal :=  StrTran(cVal,"$"+LTrim(Str(nMatch-1)),aMatches[nMatch])
         NEXT
      ENDIF
   NEXT
   //Pad to 25 characters
   cVal := Pad(cVal,25)
RETURN cVal

STATIC FUNCTION CopyAttToTemp(oAtt)
   LOCAL cTempPath := GetEnv("temp")

   oAtt:CopyOut(cTempPath,oAtt:FileName)

RETURN cTempPath+"\"+oAtt:FileName

STATIC FUNCTION JsonEncodeFormatted(xVal,cValKey,cIndent,cText)   
   LOCAL nX,xVal2,cKey
   Default(@cIndent,"")  
   Default(@cText,"")
   
   cText += CRLF  
   IF ! Empty(cValKey)            
      cText += cIndent+cValKey+":"
      //cIndent += " "
      //cIndent += Space(Len(cValKey)+1)
   ELSE
      cText += cIndent
   ENDIF     
   IF ValType(xVal) == "A"            
      cText += "["
      FOR nX := 1 TO Len(xVal)
         IF nX > 1
            cText += ","
         ENDIF
         JsonEncodeFormatted(xVal[nX],,cIndent+" ",@cText)
      NEXT
      cText += CRLF+cIndent+"]"
   ELSEIF ValType(xVal) == "H"
      cText += "{"
      FOR EACH xVal2 IN xVal
         cKey := xVal2:__enumKey()
         IF ValType(cKey) == "N"
            cKey := LTrim(Str(cKey))
         ENDIF
         JsonEncodeFormatted(xVal2,cKey,cIndent+" ",@cText)
      NEXT
      cText += CRLF+cIndent+"}"
   ELSEIF ValType(xVal) == "N"
      cText += Ltrim(Str(xVal))
   ELSEIF ValType(xVal) == "L"
      cText += IF(xVal,"true","false")
   ELSEIF ValType(xVal) == "D"
      cText += DToC(xVal)
   ELSE
      cText += xVal
   ENDIF      
RETURN cText      
      