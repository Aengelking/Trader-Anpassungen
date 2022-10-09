#define CRLF Chr(13)+Chr(10)
FUNC HOOK_AFTER_MOVE_STOCK(nArtnr,cVonLager,cNachLager,nMenge,cCharge)   
   LOCAL oArt
   //LOCAL lToQS := .F.
   LOCAL lFromQS := .F.
   LOCAL lFromSperr := .F.
   LOCAL lToSperr := .F.

   NetUse("lagerort","lago")
   lago->(dbSeek(cVonLager))
   IF lago->SperrLager       
      IF lago->TempSperr .AND. Left(cNachLager,3) != "093"
         lFromQS := .T.
      ELSE
         lFromSperr := .T.
      ENDIF
   ENDIF
   lago->(dbSeek(cNachLager))
   IF lago->SperrLager      
      IF lago->TempSperr .AND. Left(cNachLager,3) != "093"
         //lToQS := .T.
      ELSE
         lToSperr := .T.
      ENDIF
   ENDIF
   IF (lFromQS .AND. lToSperr) .OR. lFromSperr
      oArt := Artikel():New()
      oArt:Load(nArtnr)
      SendMail({{"amos.engelking@engelking.de","Amos"}},Trim(oArt:Matchcode)+" wurde "+IF(lFromSperr,"ent","ge")+"sperrt.","Von Lager: "+cVonLager+CRLF+"Nach Lager:"+cNachLager+CRLF+"Menge: "+Transform(nMenge,oArt:cPicture))   
   ENDIF
         
RETURN NIL