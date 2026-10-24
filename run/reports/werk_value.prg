NetUse("werkauf","wer")
NetUse("artikel","art")
nTotal := 0
CLS
   	Do While ! wer->(Eof())
   		if wer->Status == 3 //wer->Status < 4 .AND. wer->Status >= 3
   			art->(dbSetOrder(2))
   			art->(dbSeek(Str(wer->artno,6)))

   			? wer->Aufno,art->Matchcode
   			nPreis := StCalc(wer->artno,5,99,.F.)
   			nValue := (wer->qty-wer->gelqty)*nPreis*Currate(art->money,"E")
   			?? nValue
   			//hValue["UNFERT"] += nValue
   			nTotal +=nValue

   		Endif
   		wer->(dbSkip())
   	Enddo
   	
? "Gesamtwert: "+LTrim(Str(nTotal))
Inkey(0,128)
