PROC RUN_Test_Payrexx
   LOCAL oPayrexx := PayrexxApi():New("https://api.payrexx.com/v1.0/","engelking","1tR6j06OngfDqPbD5t7zR3a9PKVXYt")
   LOCAL cResult

   CLS
   ? "Verbingung zu Payrexx"
   cResult := oPayrexx:GetSignature_Check()
   IF oPayrexx:lError
      ?? " fehlgeschlagen",oPayrexx:cErrorText
      ? cResult
      Sinkey(0)
      RETURN
   ENDIF
   ?? " erfolgreich"

   //? "Transaction id: 1"
   //? ValToPrg(oPayrexx:GetTransaction("3548d2d1"))
   IF oPayrexx:lError
      ? "Fehler:",oPayrexx:cErrorText
   ENDIF
   ? ValToPrg(oPayrexx:DeleteInvoice(247415))
   //? "Create Invoice Link"
   //? ValToPrg(oPayrexx:PostInvoice({"title"=>"Test","description"=>"TestDesc","referenceId"=>"1","purpose"=>"TestInvoice","amount"=>1,"currency"=>"EUR"}))
   Sinkey(0)

#include 'hbclass.ch'
CLASS PayrexxApi FROM RestApi
   DATA cInstance INIT ""
   DATA cApiSecret INIT ""

   METHOD New

   ERROR HANDLER _Call
ENDCLASS

METHOD New(cUrl,cInstance,cApiSecret) //Payrexx does not use an ApiKey so we do not need to pass it in either like in the RestApi Class
   ::Super:New(cUrl)
   ::cInstance := cInstance
   ::cApiSecret := cApiSecret
   ::lJsonEncode := .F.
   ::lCamelCase  := .T.
   //::bNameMap := {|cMethod| cMethod+"/" }
RETURN Self

METHOD _Call(...)
   LOCAL oEncoder := TIPEncoderUrl():New()
   LOCAL oUrl
   LOCAL oBase64 := TIPEncoderBase64():New()
   LOCAL cDgst,cBase64
   LOCAL aParams := HB_AParams()
   LOCAL hParams := {=>}
   LOCAL nID

   IF Len(aParams) >= 1 .AND. ValType(aParams[1]) == "H"
      hParams := aParams[1]
   ELSEIF Len(aParams) >= 2 .AND. ValType(aParams[2]) == "H"
      hParams := aParams[2]
   ENDIF
   IF Len(aParams) >= 1 .AND. ValType(aParams[1]) == "N"
      nID := aParams[1]
   ENDIF

   oUrl := TUrl():New("")
   oUrl:AddGetForm(hParams)
   
   cDgst := hb_hmac_sha256(oUrl:cQuery, ::cApiSecret, .T.)
   cBase64 := oBase64:Encode(cDgst)
   cBase64 := SubStr(cBase64,1,Len(cBase64)-2) //remove CR and linefeed from the end
   cEncoded := oEncoder:Encode(cBase64)
   gtSetClipboard(cEncoded)
   oUrl:AddGetForm({"ApiSignature"=>cBase64})
//Alert(oUrl:cQuery)
//AltD()
RETURN HB_ExecFromArray(::Super,__GetMessage(),{oUrl:cQuery,nID,{"instance"=>"engelking"}})