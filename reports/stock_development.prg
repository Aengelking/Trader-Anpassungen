PROC RUN_REPORTS_STOCK_DEVELOPMENT

LOCAL aList := {}
LOCAL cFile
LOCAL nKW := CWeek(Eom(Date()))
LOCAL getlist := {}
LOCAL aAvail,nStock
LOCAL cFilter
LOCAL nX,nPreis,oArt

Head("Entwicklung Lagerbestand in Zukunft")

@ 01,00 SAY "KW" GET nKW PICTURE "9999"
READ
IF LastKey() == 27
RETURN
ENDIF

NetUse("artikel","art")
NetUse("werkauf","wer")


art->(dbSetOrder( 2 ))
art->(dbGoTop())

CLS

Aadd(aList,{"Matchcode","Artikelnr","Typ","Bestand "+NiceWeek(nKw),"Differenz Bestand","Einzelpreis","Gesamt","Differenz"})
art->(dbSetFilter({|| art->Lagerart },"art->Lagerart"))
//art->(dbSeek("KS26814"))
DO WHILE ! art->(EOF())
   aAvail := GetKwQty(art->Artikelnr)
   nStock := GetKWStock(art->artikelnr,nKW,aAvail)
   IF nStock != 0 .OR. nStock != art->Bestand            
      ? art->Matchcode,nStock
      oArt := Artikel():New(.F.)
      oArt:Load(art->Artikelnr)
      nPreis := oArt:GetAvgBuyPrice(CalWD(nKW))      
      Aadd(aList,{art->Matchcode,art->Artikelnr,Trim(art->Type),nStock,nStock-art->Bestand,nPreis,nStock*nPreis,(nStock-art->Bestand)*nPreis})
   ENDIF      
   art->(dbSetFilter({|| art->Lagerart },"art->Lagerart"))
   art->(dbSkip())
   art->(dbClearFilter())
ENDDO


dbSelectArea("wer")
cFilter := "wer->Status <= 3 .AND. wer->Termin <= "+LTrim(str(nKw))+" .AND. wer->End > "+LTrim(str(nKw))
wer->(dbSetFilter({|| &cFilter },cFilter))
wer->(dbGoTop())
DO WHILE ! wer->(Eof())
   art->(dbSetOrder(2))
   art->(dbSeek(Str(wer->artno,6)))   
   
   nX := AScan(aList,{|x| x[2] == art->Artikelnr .AND. x[3] == "UNFER" },2)
   IF nX == 0        
      Aadd(aList,{art->Matchcode,art->Artikelnr,"UNFER",0,0,StCalc(wer->artno,6,99,.F.),0,0})
      nX := Len(aList)
   ENDIF
   
   nStock := wer->qty-wer->gelqty   
   aList[nX,4] += nStock
   aList[nX,5] := aList[nX,4]-art->Bestand
   aList[nX,7] := aList[nX,4]*aList[nX,6]
   aList[nX,8] := (aList[nX,4]-art->Bestand)*aList[nX,6]
   
   ? art->Matchcode,wer->Qty-wer->GelQty   

   wer->(dbSkip())
ENDDO
wer->(dbClearFilter())

cFile := Path("export\stock_"+NiceWeek(nKW)+".csv")
SaveAsCSV(cFile,aList)
WAPI_ShellExecute(NIL, "Open", cFile, "", "", 1)
? "done"
SInkey(0)