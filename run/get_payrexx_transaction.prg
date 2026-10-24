FUNCTION RUN_GET_PAYREXX_TRANSACTION()
   LOCAL cOpenSSLDir := "C:\OpenSSl-Win32\Bin\"
   LOCAL cCurlDir    := "C:\Curl\bin\"
   LOCAL cApiSignature,cApiBinary
   LOCAL cParams := "" //"amount=1"
   LOCAL nId := 728180

   cApiBinary := __RunCmd(cOpenSSLDir+'openssl dgst -sha256 -hmac "1tR6j06OngfDqPbD5t7zR3a9PKVXYt" -binary',cParams)
   cApiSignature := StrTran(StrTran(__RunCmd(cOpenSSLDir+'openssl enc -base64',cApiBinary),Chr(13),""),Chr(10),"")
   //Alert(__RunCmd(cCurlDir+'curl.exe --request GET "https://api.payrexx.com/v1.0/SignatureCheck/?instance=engelking" --data-urlencode "ApiSignature='+cApiSignature+'"'))
   //FOR nID := 1 TO 10
   Alert(__RunCmd(cCurlDir+'curl.exe --request GET "https://api.payrexx.com/v1.0/Transaction/'+LTrim(Str(nId))+'/?instance=engelking" --data-urlencode "'+cParams+'" --data-urlencode "ApiSignature='+cApiSignature+'"'))
   //NEXT
RETURN ""
   
   
   STATIC Function __RunCmd(cCmd,cIn)
      LOCAL nProc
      LOCAL cData,cLine,nBytes
      LOCAL nStdOut,nStdIn
      nProc := HB_OpenProcess(cCmd,@nStdIn,@nStdOut,,.T.)
      IF ValType(cIn) == "C"
         FWrite(nStdIn,cIn)
         FClose(nStdIn)
      ENDIF
      cData := ""
      DO WHILE HB_ProcessValue(nProc,.F.) == -1
         cLine := Space( 1000 )
         nBytes := Fread( nStdOUT, @cLine, Len(cLine) )
         cData += SubStr(cLine,1,nBytes)
      ENDDO
      //cData := StrTran(StrTran(cData,Chr(13),""),Chr(10),"")
RETURN cData
