PROC RUN_TEST_BREVO
   LOCAL oBrevo := RestApi():New()
   LOCAL hData,aHeader

   oBrevo:cBaseUrl := "https://api.brevo.com/v3/smtp/"   

   hData := {"to"=> {{"email"=>"amos@engelking.one","name"=>"Amos"}},"templateId"=>2}   
   hData["params"] := {"anrede"=>"Guten Tag!","link"=>"https://portal.engelking.de/test"}
   aHeader := {"accept: application/json","content-type: application/json"}
   Aadd(aHeader,"api-key: SCHLUESSEL_ENTFERNT")

   CLS

   ? ValToPRg(oBrevo:Execute("email","POST",hData,aHeader,.T.))

   Sinkey(0)



   


