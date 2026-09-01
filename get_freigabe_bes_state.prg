FUNCTION HOOK_GET_FREIGABE_BES_STATE(cState,lFrei,lSonder,nMenge,dBis,nVerbraucht,nAddress,nContact,cPrev,nArtnr,nSupplier)

LOCAL oArt := Artikel():New()
LOCAL aIncome,nIncome,hRet,cNextLevel,nMaxCost
LOCAL hPrice,nPrice := 0,nX

HB_SYMBOL_UNUSED(nAddress)
HB_SYMBOL_UNUSED(nContact)
HB_SYMBOL_UNUSED(cPrev)

oArt:Load(nArtnr)

nMaxCost := 120

hRet := {"LBES"=>.F.,"NMAXQTY"=>0}

IF Tr_Getini(28) == 9
   //RETURN {"LBES"=>.T.,"NMAXQTY"=>300}
ENDIF

IF oArt:Type == "UNFER"
   NetUse("parts","part")
   IF ! part->(dbSeek(STR(art->artikelnr,6)+Str(-1,3)))
      hRet:lBes := .T.       //unfertige Erzeugnisse die wir selbst fertigen brachen keine Freigabe
      RETURN hRet
   ENDIF
ENDIF

cNextLevel := cState
If lFrei .OR. cState == ""
   IF Tr_GetINi(28) == 9
      //Alert(ValToprg({cState,lFrei,lSonder,nMenge,dBis,nVerbraucht,nAddress,nContact,cPrev,nArtnr,nSupplier}))
   ENDIF
	cNextLevel := GetNextFreigabeLevel(nArtnr,nSupplier,cState)   
Endif

IF Tr_Getini(28) == 9
   //Alert(cState+" -> "+cNextLevel+IF(lFrei,""," nicht")+" freigegeben")
ENDIF

IF Trim(art->Type) == "RHB" .AND. cNextLevel $ {"DONE","MUS"}
   hRet:nMaxQty := 1000
   hRet:lBes := .T.   
ELSEIF cNextLevel == "MUS" .OR. ;
   (nSupplier == 0 .AND. cNextLevel == "KU") .OR.; //Interne Produktion
   (cState == "KU" .AND. cNextLevel == "KU") //das ist der Fall, wenn der Kunde die Muster ablehnt
	hRet:lBes        := .T.
   hRet:nMaxQty     := 4 //restrict everthing to four pieces, except the expections below 
   IF Tr_Getini(28) == 9
      //Alert("Musterfreigabe fr "+art->Matchcode+" Gruppe: "+art->Gruppe)
   ENDIF
   IF art->Gruppe == "KANK" //Netzkabel            
      hRet:nMaxQty     := 1000
   ELSEIF oArt:Manufactur == 6 //Engelking
      hRet:nMaxQty     := 500
   ELSEIF oArt:Manufactur == 5 //Engelking China
      hRet:nMaxQty     := 11   //10 for the customer and one for us
   ELSE      
      NetUse("engkund","ku")
      ku->(dbSetOrder( 8 ))
      ku->(dbSeek( Str(nSupplier,6) ))

      IF ! oArt:IsManufactured
         hPrice := oArt:GetBuyPrice(ku->Kunde,-1)
         nPrice := hPrice["price"]/hPrice["unit"]
      ELSE
         IF Date() <= StoD("20251103")
            hRet:nMaxQty := 11
         ENDIF
         //this needs testing
         /*hPrice := RUN_GetCostFromOO(art->Artikelnr)
         IF HHasKey(hPrice,"DATA")
            FOR nX := 1 TO Len(hPrice["DATA"])
               IF hPrice["DATA"][nX]["QTY"] != 0 .AND. (nPrice == 0 .OR. hPrice["DATA"][nX]["COST"] < nPrice)
                  nPrice := hPrice["DATA"][nX]["COST"]
               ENDIF
            NEXT
         ENDIF*/
      ENDIF
      IF nPrice != 0
         IF Tr_Getini(28) == 9
            Alert("MaxCost: "+Str(nMaxCost)+" Price: "+Str(nPrice)+" Qty: "+Str(nMaxCost/nPrice))
         ENDIF         
         hRet:nMaxQty := Max(Round( nMaxCost/nPrice, GetMeDecimals( oArt:Me )),2)
      ELSEIF Left(art->Gruppe,2)=="KO"
         hRet:nMaxQty := 10
      ENDIF      
      IF Tr_Getini(28) == 9
      //   Alert("Freigabe fr "+art->Matchcode+" mit Preis "+Str(nPrice)+" und MaxQty "+Str(hRet:nMaxQty))
      ENDIF
	ENDIF
ELSEIF cState == "" .AND. cNextLevel == "VMU" //Freigabe noch nicht begonnen, Vorserien Muster
   hRet:lBes        := .T.
   hRet:nMaxQty     := 10 //1 for the customer and one for us
ELSEIF cNextLevel == "ZNG" .AND. (Left(oArt:Matchcode,2) == "BA" .OR. Trim(oArt:Matchcode) $ {"KS28074/1"})  //Beschaffungsartikel
   hRet:lBes        := .T.
ELSEIF cState == "DONE"
   
	If lSonder
	   NetUse("engbes","bes")
      bes->(dbSetOrder(4))
      //aIncome := bes->(LETO_SUM("beqty,gelqty","beqty-gelqty>0 .AND. bestat < 3",art->Matchcode,art->Matchcode))
      //nIncome := aIncome[1]-aIncome[2]
      //Alert(Str(nIncome))
      nIncome := 0 //this is done in the bestellprog.
      NetUse("werkauf","wer")
      wer->(dbSetOrder(2))
      //aIncome := wer->(LETO_SUM("qty,gelqty","status == 3",Str(art->Artikelnr,6),Str(art->Artikelnr,6)))  //wir betrachten nur in Fertigung befindliche Auftr„ge, da diese nicht ausgel”st werden wenn keine ausreichende Freigabe vorhanden ist
      //nIncome += aIncome[1]-aIncome[2]
      
		hRet:lBes := .T.
		IF ! Empty(dBis)
			hRet:lBes := dBis >= Date()
		ENDIF
		hRet:lBes :=  hRet:lBes .AND. nVerbraucht+nIncome < nMenge
		hRet:nMaxQty := (nMenge-nVerbraucht-nIncome)
	Else
		hRet:lBes := .T.
	Endif
ENDIF

IF Tr_Getini(28) == 9 
   //Alert(art->Matchcode+";Next: "+cNextLevel+";"+ValToPrg(hRet))
   /*hRet:lBes := .T.
   hRet:nMaxQty := 7*/
   IF ! hRet:lBes //for returns
      IF nSupplier == 31330
         hRet:lBes := .T.
         hRet:nMaxQty := 1
         RETURN hRet
      ENDIF
   ENDIF
ENDIF

//this does not work on the webserver
//#include 'x:\run\OO_costing.prg'

Return hRet
