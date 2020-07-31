#define CURL2 "C:\Programme\Curl\bin\curl.exe"
#define CURL "Y:\Curl\curl-7.67.0-win32-mingw\bin\curl.exe"

FUNCTION __DownLoadPage(cUrl,hPost,lModAgent)
   LOCAL nStdOut := 0
   LOCAL cData := ""
   LOCAL nBytes,cValue
   LOCAL nProc,cLine
   LOCAL cCommand
   Default(@lModAgent,.T.)
   IF ! File(CURL)
      cCommand := CURL2
   ELSE      
      cCommand := CURL
   ENDIF
   cCommand += ' -L'
   IF lModAgent
      cCommand += ' --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.186 Safari/537.36"'
   ENDIF
   cCommand += ' "'+cUrl+'"'
   
   
   IF HB_IsHash(hPost)
      cCommand += ' -X POST -d"'
      FOR EACH cValue IN hPost
          IF cValue:__enumIndex() > 1
             cCommand += "&"
          ENDIF
          ? cValue:__eNumKey()
          //cCommand += cValue:__eNumKey()+"="+cValue
      NEXT
      cCommand += '"'
   ENDIF
   nProc := HB_OpenProcess(cCommand,,@nStdOut,,.T.)
   DO WHILE HB_ProcessValue(nProc,.F.) == -1
      cLine := Space( 1000 )
      nBytes := Fread( nStdOUT, @cLine, Len(cLine) )
      cData += SubStr(cLine,1,nBytes)
   ENDDO
RETURN cData

