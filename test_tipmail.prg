PROC Test_TipMail
   LOCAL oMail := TipMail():New()

   oMail:setBody("Hello World")
   oMail:setHeader( "Subject: Hello Wolrd", "amos.engelking@engelking.de", "amos@engelking.one") ///, xCC, xBCC )
   MemoWrit("C:\Users\Amos\AppData\Local\Temp\3\amos.eml",oMail:toString())