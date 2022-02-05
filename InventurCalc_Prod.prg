Function RUN_InventurCalc_Prod()
      LOCAL hValue := {"WARE"=>0,"RHB"=>0,"UNFERT"=>0}
      LOCAL nType  := IF(GetConfigValue("INVENTUR_PRICEBASE")=="EK",1,2)
      LOCAL nValue,nPreis,cProtokoll,nPH
      LOCAL aUnfer := {},nX,nBestand
      LOCAL oArt,nID
      LOCAL cOwner

      cProtokoll := Wvt_GetSaveFileName( 0,"" , "CSV Datei", { {"CSV Datei (*.csv)","*.csv"},{"Alle Dateien (*.*)","*.*"} } )
      //Path("\export\inventur_"+DToS(Date())+"_"+StrTran(Time(),":","-")+".csv")
      nPH := FCreate( cProtokoll )
      FWrite(nPH,"Matchcode;Artikelnummer;Bestand;Artikelart;Einzelpreis;Gesamtwert;Abteilung"+Chr(13)+Chr(10))
      NetUse("inventur","inv")
      NetUse("artikel","art")
      NetUse("werkauf","wer")
      NetUse("me","me")
      NetUse("parts","part")

      NetUse("ID","ID")

      @ 07,01 SAY "Inventur"
      //@ 02,VPOS SAY "von "+mrec
      art->(dbGoTop())
   	Do While ! art->(Eof())
   		If art->Bestand > 0
            @ 07,10 SAY art->Matchcode
            IF art->Manufactur == 6 .OR. Left(art->Matchcode,3) == "WID" .OR. Left(art->Matchcode,4) == "KOND"
               cOwner := "PROD"
            ELSE
               cOwner := ""
            ENDIF
   			IF nType == 2
   				oArt := Artikel():New(.F.)
               oArt:Load(art->Artikelnr)
               nPreis := oArt:GetAvgBuyPrice(Date())
            ELSE
      			nPreis := art->letzte_ek/art->pe*Currate(art->money,"E")
      			If art->Bezug >= 5
      				nPreis := StCalc(art->artikelnr,1,99,.T.)
      			Endif
      		ENDIF
   			nValue := art->Bestand*nPreis
//   			@ 09,36 SAY Str(nValue,12,2)
   			If Trim(art->Type) == "RHB"
               hValue["RHB"] += nValue
               cOwner := Str(_FindTopPart())
               IF _FindTopPart() == 6
                  cOwner := "PROD"
               ENDIF
   			Elseif Trim(art->Type) == "UNFER"
   				hValue["UNFERT"] += nValue
   			Else
   				hValue["WARE"] += nValue
   			Endif
   			IF Trim(art->Type) != "UNFER"
      			FWrite(nPH,Trim(art->Matchcode)+";"+LTrim(Str(art->Artikelnr))+";"+StrTran(LTrim(Transform(art->Bestand,ME(art->Me))),".",",")+";" )
   			   If Trim(art->Type) == "RHB"
      				FWrite(nPh,"RHB")
      			ELSE
      				FWrite(nPh,"Ware")
      			ENDIF
      			FWrite(nPH,";"+StrTran(LTrim(Str(nPreis)),".",",")+";"+StrTran(LTrim(Str(art->Bestand*nPreis)),".",",")+";"+cOwner+Chr(13)+Chr(10))
      		ELSE
      		    nX := AScan(aUnfer,{|x| x["ARTIKELNR"] == art->Artikelnr})
      		    IF nX == 0
                   Aadd(aUnfer,{"ARTIKELNR"=>art->Artikelnr,"PREIS"=>nPreis,"BESTAND"=>0})
                   nX := Len(aUnfer)
                ENDIF
                aUnfer[nX]["BESTAND"] +=art->Bestand
            ENDIF
   		Endif
   		art->(dbSkip())
   	Enddo
   	wer->(dbGoTop())
   	Do While ! wer->(Eof())
   		if wer->Status == 3 //wer->Status < 4 .AND. wer->Status >= 3
   			art->(dbSetOrder(2))
   			art->(dbSeek(Str(wer->artno,6)))

   			@ 07,10 SAY art->Matchcode
            nX := AScan(aUnfer,{|x| x["ARTIKELNR"] == art->Artikelnr})
            IF nX != 0
               nPreis  := aUnfer[nX]["PREIS"]
            ELSE
   			   nPreis := StCalc(wer->artno,If(nType==2,6,1),99,.F.)
   			   //nPreis *= Currate(art->money,"E")
   			   Aadd(aUnfer,{"ARTIKELNR"=>art->Artikelnr,"PREIS"=>nPreis,"BESTAND"=>0})
               nX := Len(aUnfer)
   			ENDIF
            aUnfer[nX]["BESTAND"] += wer->qty-wer->gelqty
   			nValue := (wer->qty-wer->gelqty)*nPreis
   			hValue["UNFERT"] += nValue

   		Endif
   		wer->(dbSkip())
   	Enddo
      FOR nX := 1 TO LEN(aUnfer)
         art->(dbSeek( Str(aUnfer[nX]["ARTIKELNR"],6) ))
         nPreis := aUnfer[nX]["PREIS"]
         nValue := aUnfer[nX]["PREIS"]*aUnfer[nX]["BESTAND"]
         nBestand := aUnfer[nX]["BESTAND"]
   		
         FWrite(nPH,Trim(art->Matchcode)+";"+LTrim(Str(art->Artikelnr))+";"+StrTran(LTrim(Transform(nBestand,ME(art->Me))),".",",")+";"+"Unfertig"+";"+StrTran(LTrim(Str(nPreis))+";"+LTrim(Str(nValue)),".",",")+Chr(13)+Chr(10) )
      NEXT
   	FClose(nPH)
   	inv->(dbGoBottom())

   	IF inv->Ware != Round(hValue["WARE"],2) .OR. inv->RHB != Round(hValue["RHB"],2) .OR. inv->Unfertig !=  Round(hValue["UNFERT"],2)
   	   IF ! id->(dbSeek( "INV" ))
            id->(Add_Rec(0))
            id->Alias := "INV"
         ELSE
            id->(Rec_Lock(0))
         ENDIF
         nID   := id->ID+1
         id->ID := nID
         id->(dbUnLock())

      	inv->(Add_Rec())
      	inv->ID       := nID
         inv->Date     := Date()
      	inv->Time     := Time()
         inv->Ware     := hValue["WARE"]
         inv->RHB      := hValue["RHB"]
         inv->Unfertig := hValue["UNFERT"]
         inv->(dbUnLock())
         
         AddFileToArchive("INV",nID,cProtokoll)
      ENDIF
RETURN hValue

STATIC FUNC _FindTopPart()
   LOCAL nArtRec := art->(Recno())
   LOCAL nManu := 0

   art->(dbSetOrder( 2 ))

   part->(dbSetOrder(2))
   part->(dbSeek( Str(art->Artikelnr) , .T. ))
   IF part->PartArt == art->Artikelnr
      art->(dbSeek( str(part->ListArt,6) ))
      If Trim(art->Type) == "RHB"
         nManu := _FindTopPart()
      ELSE
         nManu := art->Manufactur
      ENDIF
   ENDIF
   art->(dbSetOrder( 1 ))
   art->(dbGoTo(nArtRec))
RETURN nManu
