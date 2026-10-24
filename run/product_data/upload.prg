/**
 * Upload Module for Product Data Export
 */

#include "x:\run\product_data\config.prg"

FUNCTION UploadProductData(cQuoteFile, hConfig)
   LOCAL cCmd, nStdOUT, nProc, cData, cLine, nBytes, nSecond
   LOCAL hData, lSuccess
   
   IF GetConfigValue("BATCHMODE") .OR. Tr_MsgBox("Run upload script?",,{"Yes","No"}) == 1
      // Build curl command for API upload
      cCmd := 'c:\curl\bin\curl -s -X POST https://conradb2b-prod.mirakl.net/api/offers/imports '
      cCmd += '-H "Authorization: 17ba0a0c-4b84-4fd1-8523-543517da2079" '
      cCmd += '-H "Content-Type: multipart/form-data" '
      cCmd += '-F "file=@' + cQuoteFile + '" '
      cCmd += '-F "import_mode=REPLACE" -F "operator_format=true" -F "with_products=false"'
      
      nStdOUT := 0
      nProc := HB_OpenProcess(cCmd,, @nStdOut,, .T.)
      cData := ""
      
      nSecond := Seconds()
      DO WHILE HB_ProcessValue(nProc, .F.) == -1
         cLine := Space(1000)
         nBytes := Fread(nStdOUT, @cLine, Len(cLine))
         cData += SubStr(cLine, 1, nBytes)
         
         IF Seconds() - nSecond > 30  // Timeout after 30 seconds
            ? "timeout"
            EXIT
         ENDIF
      ENDDO
      
      // Check if upload was successful
      hData := HB_JsonDecode(cData)
      lSuccess := ValType(hData) == "H" .AND. HHasKey(hData, "import_id")
      
      IF ! lSuccess
         SendMail({{"amos.engelking@engelking.de","Amos"}}, "Conrad Upload Error", cData)
      ENDIF
   ENDIF
   
RETURN lSuccess

FUNCTION CreateQuoteFile(cQuoteFile)
   LOCAL nH2, oErr
   
   DO WHILE (nH2 := IF(File(cQuoteFile), FOpen(cQuoteFile,1), FCreate(cQuoteFile,0))) == -1
      IF GetConfigValue("BATCHMODE")
         oErr := ErrorNew()
         oErr:SubSystem   := "PRODUCT-DATA-UPLOAD"
         oErr:Description := "File creation error (" + cQuoteFile + " Error: " + LTrim(Str(FError())) + ")"
         Throw(oErr)
      ELSEIF Tr_MsgBox("Datei konnte nicht erstellt werden (ERROR: " + LTrim(Str(FError())) + ")",,{"erneut versuchen","abbrechen"}) == 2
         RETURN -1
      ENDIF
   ENDDO
   
RETURN nH2
