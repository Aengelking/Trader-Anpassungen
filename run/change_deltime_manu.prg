#define CRLF Chr(13)+Chr(10)
PROC RUN_CHANGE_DELTIME
LOCAL aManu,nManu := 1
LOCAL nLZ := 1
LOCAL nCount
LOCAL oExtra
LOCAL getlist := {}
LOCAL cList := ""
LOCAL lNotChanged := .F.,lFound

NetUse("manufact","manu")
NetUse("artikel","art")
NetUse("artlief","ali")
NetUse("engkund","ku")

Head(t("Beschaffungszeit an Herstellerlieferzeit anpassen"))

//Lieferzeiten anhand ali + X wochen anpassen

//@ 03,00 SAY "Laufzeit in Wochen" GET nLZ PICTURE "99"
//READ

IF LastKey() == 27 .OR. Tr_MsgBox(t("Wirklich alle Produkte ändern"),,{"Nein","Ja"}) != 2
   RETURN
ENDIF

art->(dbSetFilter( {|| !art->Obsolete} ,"!Obsolete"))
art->(dbGoTop())
ku->(dbSetOrder( 8 ))
nCount := 0
cList := Pad("Matchcode",25)+"|"+Pad("Alt",3)+"|"+Pad("Neu",3)+"|"+Pad("Hersteller",20)+CRLF

art->(dbSeek("CMI",.T.))
DO WHILE ! art->(EOF())
   
   @ MaxRow(),00 SAY art->Matchcode
   manu->(dbSeek( Str(art->Manufactur,5) ))
   //? manu->Short
   ali->(dbSetOrder( 1 ))
   IF manu->Principal .AND. manu->Address != 0 .AND. ku->(dbSeek(Str(manu->Address,6)))
      ?? "Manu"
      lFound := ali->(dbSeek( ku->Kunde+Str(art->Artikelnr,6) )) 
   ELSE
      ?? "Prio"
      ali->(dbSetOrder( 6 ))
      lFound := ali->(dbSeek( Str(art->Artikelnr,6)+"1" )) //supplier with priority 1
   ENDIF
   IF lFound .AND. ali->LZ != 0
      oExtra := ku->(ExtraData():New(ku->Nummer))
      nLZ := Ceiling(oExtra:RecvTime/7)
      ? art->Matchcode,manu->Short,"Aktuell:",art->LZ,"Neu:",ali->LZ+nLZ
      IF ali->LZ+nLZ < art->LZ
         ?? " nicht ver„ndert"
         lNotChanged := .T.
         cList += art->Matchcode+"|"+Str(art->LZ,3)+"|"+Str(ali->LZ+nLZ,3)+"|"+manu->Short+CRLF
      ELSEIF ali->LZ+nLZ > art->LZ
         ?? "",art->LZ,"->",ali->LZ+nLZ
         art->(Rec_Lock())
         //art->LZ := ali->LZ+nLZ
         art->(dbUnLock())
         nCount++
      ENDIF
   ENDIF
      

   
   art->(dbSkip())
   IF Inkey() == 27
      EXIT
   ENDIF
ENDDO

art->(dbClearFilter())
IF lNotChanged
   SendMail({{"amos.engelking@engelking.de","Amos"}},"Lieferzeiten nicht ge„ndert","Die folgenden Produkte wurden nicht ge„ndert, da die Herstellerslieferzeit kleiner ist als die Artikel-Lieferzeit:"+CRLF+cList)
ENDIF

? nCount,t("Produkte geändert")

SInkey(0)