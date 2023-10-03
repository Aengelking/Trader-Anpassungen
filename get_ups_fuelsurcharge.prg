
#include 'y:\hb34\contrib\hbcurl\hbcurl.ch'

FUNCTION RUN_GET_UPS_FUELSURCHARGE
      LOCAL pCurl := Curl_Easy_Init()
      LOCAL cUrl := "https://www.ups.com/assets/resources/fuel-surcharge/de.json"
      LOCAL cData,hData,hSurcharge
      
      /*curl_easy_setopt(pCurl, HB_CURLOPT_SSL_VERIFYPEER,0)
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_SETUP )
      curl_easy_setopt(pCurl, HB_CURLOPT_URL, cUrl )
      curl_easy_setopt(pCurl, HB_CURLOPT_HTTPHEADER, {"User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36"})
      
      Curl_Easy_Perform(pCurl)
      
      curl_easy_setopt(pCurl, HB_CURLOPT_DL_BUFF_GET, @cData )
      
      Curl_Easy_CleanUp(pCurl)*/

      cData := __DownLoadPage(cUrl)

      hData := HB_JsonDecode(cData)

      IF hData == NIL .OR. ! HHasKey(hData,"FuelSurchargeResponse")
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Fehler beim herunterladen der UPS Fuel Surcharge Tabelle",cData)   
         RETURN NIL
      ENDIF
      
      hSurcharge := hData["FuelSurchargeResponse"]["SurchargeHistory_de"]["RevenueSurchargeHistory"][1]

      hData := {"DATE"=>StrTran(hSurcharge["Field1"],"/","."),"STANDARD"=>_SToN(hSurcharge["Field2"])/100,"EXPRESS-EU"=>_SToN(hSurcharge["Field3"])/100,"NON-EU"=>_SToN(hSurcharge["Field4"])/100}
      MemoWrit(Path("ups_fuel.json"),HB_JsonEncode(hData))
      /*CLS
      ? "Date:",CtoD(StrTran(hSurcharge["Field1"],"/","."))
      ? "Standard:",_SToN(hSurcharge["Field2"])
      ? "Express EU:",_SToN(hSurcharge["Field3"])
      ? "Non-EU:",_SToN(hSurcharge["Field4"])
      SInkey(0)*/
RETURN NIL

STATIC FUNCTION _SToN(cData)
RETURN Val(StrTran(StrTran(cData,"%"),",","."))

#include 'curl.prg'

