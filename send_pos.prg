FUNCTION RUN_SEND_POS()
   LOCAL nYear := Year(Date()),nMonth := Month(Date())
   LOCAL aData
   LOCAL cPW,cFile,cDir
   LOCAL cLang,cText
   LOCAL lBatch
   IF nMonth > 1
      nMonth := nMonth-1
   ELSE
      nMonth := 12
      nYear -= 1
   ENDIF
   
   //ITW
   cDir := "\\EK-Server4\data\Dokumente und Einstellungen\Amos\Documents\ITW\POS\"
   cFile := cDir+"POS_ITW_"+Str(nYear,4)+"-"+StrZero(nMonth,2)+".xls"
   lBatch := GetConfigValue("BATCHMODE")
   SetConfigValue("BATCHMODE",.T.)
   aData := Bericht_Pos(2,nYear,nMonth,3,1,"EN") 
   SetConfigValue("BATCHMODE",lBatch)
   cPW := MemoRead(cDir+"pw.txt")
   SaveToOO(cFile,aData,cPW,"XLS") //we use XLS as the Password does not work with XSLX
   
   cLang := HB_LangSelect("EN")
   cText := "Dear Steve,<p>Please find the current POS data attached.</p>Best Regards<br />Amos"

   cText += "<br /><br /><b>Engelking Elektronik GmbH</b><br />"
   cText += "Albstrasse 16<br />"
   cText += "D-78609 Tuningen<br />"
   cText += "Germany<br />"
   cText += "http://www.engelking.de<br /><br />"
   cText += "eMail: amos.engelking@engelking.de<br />"
   cText += "Tel: +49-7464-9865-15<br />"
   cText += "Fax: +49-7464-986571<br /><br />"
   cText += "Amtsgericht Freiburg (HRB 602241)<br />"
   cText += "GeschÑftsfÅhrer: Amos Engelking, Hans-Peter Schwei·"
   SendMail({{"amos.engelking@engelking.de","Amos"}},"POS "+CMonth(StoD(Str(nYear,4)+StrZero(nMonth,2)+"01"))+" "+Str(nYear,4),cText,{cFile},,,.T.,"amos.engelking@engelking.de")
   
   HB_LangSelect(cLang)
RETURN .T.

#include "x:\run\reports\pos.prg"
#include 'X:\run\savetooo.prg'