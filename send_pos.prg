FUNCTION RUN_SEND_POS()
   LOCAL nYear := Year(Date()),nMonth := Month(Date())
   LOCAL aData
   LOCAL cPW,cFile,cDir
   LOCAL cLang,cText
   LOCAL lBatch
   LOCAL hPos,aPos

   NetUse("manufact","manu")

   IF nMonth > 1
      nMonth := nMonth-1
   ELSE
      nMonth := 12
      nYear -= 1
   ENDIF

   //make sure OO us running
   Wapi_ShellExecute(NIL,"open","C:\Program Files\LibreOffice\program\soffice.exe") //,"--invisible")
/**/
      
   aPOS := {;
      ;//ITW
      {"DIR"=>"\\EK-Server4\data\Dokumente und Einstellungen\Amos\Documents\ITW\POS\",;
      "PW"=>.T.,;
      "ANREDE"=>"Dear Steve",;
      "MANUFACTURER"=>3,;
      "TYPE"=>1},;
      ;//BULGIN
      {"DIR"=>"\\EK-Server4\data\Dokumente und Einstellungen\Amos\Documents\Lieferanten\Bulgin\POS\",;
      "PW"=>.F.,;
      "ANREDE"=>"Hello",;
      "MANUFACTURER"=>1,;
      "TYPE"=>3};
   }

   //ITW
   lBatch := GetConfigValue("BATCHMODE")
   SetConfigValue("BATCHMODE",.T.)
   FOR EACH hPos IN aPos
      manu->(dbSeek( Str(hPos:Manufacturer,5) ))

      aData := Bericht_Pos(2,nYear,nMonth,hPos:Manufacturer,hPos:Type,"EN")       

      SetConfigValue("BATCHMODE",lBatch)
      IF hPos:PW
         cPW := MemoRead(hPos:Dir+"pw.txt")
      ELSE
         cPW := ""
      ENDIF

      cFile := hPos:Dir+"POS_"+Trim(manu->Short)+"_"+Str(nYear,4)+"-"+StrZero(nMonth,2)+".xls"
      SaveToOO(cFile,aData,cPW,"XLS") //we use XLS as the Password does not work with XSLX

      cLang := HB_LangSelect("EN")
      cText := hPos:Anrede+"<p>Please find the current POS data attached.</p>Best Regards<br />Amos"

      cText := LoadEmailConfigFile("header")+cText+LoadEmailConfigFile("footer")
      
      SendMail({{"amos.engelking@engelking.de","Amos"}},"POS "+Trim(manu->Short)+" "+CMonth(StoD(Str(nYear,4)+StrZero(nMonth,2)+"01"))+" "+Str(nYear,4),cText,{cFile},,,.T.,"amos.engelking@engelking.de")
   NEXT
   HB_LangSelect(cLang)
RETURN .T.

#include "x:\run\reports\pos.prg"
#include 'X:\run\savetooo.prg'