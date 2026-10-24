FUNCTION RUN_STOCK_RS(nArtnr,cArtlief)
LOCAL oHttp
LOCAL cSid
LOCAL cData
LOCAL hCookies,hPath
LOCAL cValue
LOCAL aSites := {"de"} //,"uk","fr"}
LOCAL lD :=  .F. //Tr_Getini(28) == 9  //debug
LOCAL nQty := 0
LOCAL lFound := .F.
LOCAL nP := 29
LOCAL nX,nR,cUrl,cScr,aMatch

MEMVAR c_two

#define GZIP "C:\Program Files (x86)\GnuWin32\bin\gzip.exe"



FOR nX := 1 TO Len(aSites)
   IF Type("nR") == "N"
      @ nR,24 SAY Replicate(".",nX)
   ENDIF

   cUrl := "https://de.rs-online.com/web/p/products/"+Trim(cArtlief)+"/"
   cData := __DownloadPage(cUrl)

   //oHttp := TIpClientHttp():new( cUrl )
   /*oHttp:hFields[":authority"] := "de.rs-online.com"
   oHttp:hFields[":method:"] := "GET"
   oHttp:hFields[":path"] := "/web/p/products/3444009/"
   oHttp:hFields[":scheme"] := "https"*/
//   oHttp:hFields["accept"] := "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8"
/*   oHttp:hFields["accept-encoding"] := "gzip, deflate, br"
   oHttp:hFields["accept-language"] := "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,nl;q=0.6"
   oHttp:hFields["cookie"] := 'ADRUM=s=1521725609588&r=https%3A%2F%2Fde.rs-online.com%2Fweb%2Fp%2Fproducts%2F3444009%2F%3F0; _4c_=fVLfa9swEP5Xhh76lOiXJVkKhJGWvgy20m3Qx2FLMjGxLSMpy7aS%2F72nJB1tBrONfHe%2B%2B767%2B%2FyMDls%2FoRWTnNVcKmrgWaCd%2F53Q6hnZuZw%2Fy7GPA1qhbc5zWhHiPI5pGaahnzy2YSQH35KZzDG4vc2JVEIISg1BC2SD81DJDFaYgZ%2F%2FgLdUFMw2hkPyEfy7bQyj%2F6AERDsgRYIb1jVU86phtDFUmwZeXnjbtYo3BvICtIie%2BskBCLjRdz7GExp4qc%2BF9V2TlzAMd%2FoCkTlMfsppyG6535XefBwLKpgPn79%2F%2FXF7v7l7%2BPJm7qsq7CqcLA5jjs7iyWfSkpTeZZWVLN4G3ClEGCWfvi05FpiSRJnRMKqsKg73x83j7ZrdjL1bK1YbJoSuBGhTV%2BDWvJaCaUo55YpzSYUWN5vH%2B3XZ7QxSoWIMwTZDWQDs%2FrhAv84Ka8aMMbWuYdIMcmoFIsEFGbF3F6mRtoJqKUVDjbSe184Db8esNaJpW6kA%2FoxnJGUS8KQAgBnwTvXsL11dARvQ0QsdDPJKVxq9yn5tTv7b3Pk%2F%2BU%2BNvq45Hl8A; RT="dm=rs-online.com&si=d26f71bb-a5ba-42ee-80da-0951e306da3d&ss=1521725442913&sl=4&tt=34461&obo=0&sh=1521725599136%3D4%3A0%3A34461%2C1521725552312%3D3%3A0%3A27586%2C1521725482642%3D2%3A0%3A19524%2C1521725452714%3D1%3A0%3A9761&bcn=%2F%2F364bf6cc.akstat.io%2F&r=https%3A%2F%2Fde.rs-online.com%2Fweb%2Fp%2Fproducts%2F3444009%2F&ul=1521725609549&hd=1521725609709"'
   oHttp:hFields["upgrade-insecure-requests" := "1"*/
   /*oHttp:cUserAgent := "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.84 Safari/537.36"
   oHttp:nConnTimeout := 20000
   oHttp:lPersistent := .T.
  //Alert(oHttp:cUserAgent)
   If oHttp:open()
      cData := oHttp:ReadAll()  */
      //cData := __DownloadPage(cUrl)

      If lD
         cScr := SaveScreen()
         CLS
         //@ 00,00 SAY "Initial Response" COLOR c_two
         MemoEdit(cData,01,00,MaxRow(),MaxCol())
         RestScreen(,,,,cScr)
         hb_gtInfo( 15, cData )
      Endif
      If ValType(cData) != "C" .OR. Empty(cData)
         //cData := ""
         EXIT
      Endif
      aMatch := HB_Regex("([0-9\.]{1,})\s*Lieferbar",cData,.F.)
      IF Len(aMatch) >= 2
         lFound := .T.
         nQty := Val(aMatch[2])
      ENDIF

  /* Endif
   oHttp:close()*/
NEXT

If lFound
   Return nQty
Else
   Return -1
Endif

#include 'X:\run\curl.prg'
