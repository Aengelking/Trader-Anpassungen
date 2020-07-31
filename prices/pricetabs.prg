//#include 'hbthread.ch'
FUNCTION RUN_PRICES_PRICETABS( nArtnr,dDate )

LOCAL nLast := 99999999,aPriceTabs := {},cSupplier,nMOQ
LOCAL nMenge
LOCAL cWald := Pad("WALDOM",8)
LOCAL lDbg := .F. // Tr_Getini(28) == 9
LOCAL aBuy,nEK,nMarg,nVK,nX
LOCAL aUseAvg := {"PX0686"}
LOCAL oArtikel,nAvgBuy

NetUse("compprice","cmpr")
NetUse("manufact","manu")
netUse("engkund","ku")
NetUse("artlief","ali")

IF ! cmpr-> (dbSeek( Str(art->Artikelnr,6) )) .OR. cmpr->Datum < Date()-3
   IF ! MBaseRun(Trim(Tr_getini(1))+"\run\prices\updcompet",,.T.)
      RETURN {}
   ENDIF
ENDIF

cmpr->(dbSeek( Str(art->Artikelnr,6) ))

aPriceTabs := GetPrices(art->Artikelnr,IF(art->Manufactur == 14,77,1),dDate)
IF lDbg 
   Alert(ValToPrg(aPriceTabs))
ENDIF

manu->(dbSeek( Str(art->Manufactur,5) ))
ku->(dbSetOrder( 8 ))
ku->(dbSeek( Str(manu->Address,6) ))

nEK := 0
IF art->Manufactur == 1 .OR. art->Manufactur == 10     
   aBuy := GetBuyPrice(cWald,art->Artikelnr,-1, , , ,dDate)
   IF aBuy["price"] == 0 .AND. dDate != Date()
      //Alert("No Waldom buy price at the set date")
      aBuy := GetBuyPrice(cWald,art->Artikelnr,-1, , , ,Date())
   ENDIF
   nEk := aBuy["price"]/aBuy["unit"]
   IF lDbg
      Alert("Waldom buy price: "+LTrim(Str(nEk)))
   ENDIF
ENDIF
aBuy := GetBuyPrice(ku->Kunde,art->Artikelnr,-1, , , ,dDate)
IF nEK == 0     
   nEk := aBuy["price"]/aBuy["unit"]*Currate(ku->Money,"E")
ENDIF
nMOQ := aBuy["qty"]
IF ValType(nMOQ) == "U" //old bug in GetBuyPrice
   nMoq := 1
ENDIF

oArtikel := Artikel():New()
oArtikel:Load(art->Artikelnr)
nAvgBuy := oArtikel:GetAvgBuyPrice(Date())
/*IF nAvgBuy > 0 .AND. nAvgBuy < nEK   //do not understand this, if the price from the manufacturer rises we should only use the avgbuyprice if we have stock
   nEK := nAvgBuy
ENDIF*/

ali->(dbSeek(ku->Kunde+Str(art->Artikelnr,6)))

IF lDbg
   Alert("MOQ: "+LTrim(Str(nMOQ)))
   //Alert(Str(ali->Artikelnr,6)+Str(ali->VPE))
ENDIF

IF nEk == 0
   IF lDbg
      Alert("Kein EK")
   ENDIF
   RETURN {}
ENDIF

DO WHILE cmpr->Artikelnr == art->Artikelnr

   IF cmpr->Menge > 0 .AND. cmpr->Preis > 0      
      IF ((art->Manufactur == 1 .OR. art->Manufactur == 10) .AND. cmpr->Menge < nMOQ .AND. art->Mindest == 0 ) //Bulgin or Arcolectric and under MOQ or
         IF lDbg
            Alert("WALDOM "+Str(cmpr->Menge))
         ENDIF
         aBuy := GetBuyPrice(cWald,art->Artikelnr,cmpr->Menge,,,,,Date())
         IF aBuy["price"] != 0
            nEK := aBuy["price"]/aBuy["unit"]
            //IF Tr_getini(28)==9; Alert(Str(nMOQ)+" WALDOM "+Str(nEk)); ENDIF
         ENDIF
      ELSE
         IF lDbg
            Alert("Manufacturer")
         ENDIF
         aBuy := GetBuyPrice(ku->Kunde,art->Artikelnr,cmpr->Menge,,,,dDate)
         IF aBuy["price"] != 0            
            nEK := aBuy["price"]/aBuy["unit"]
            nEk *= Currate(ku->Money,"E")
         ENDIF
      ENDIF

      IF cmpr->Menge <= oArtikel:Bestand .AND. nAvgBuy < nEK  //we have bought our stock somewhere cheaper (e.g. PX0686)
         IF lDbg
            Alert("AvgBuyPrice")
         ENDIF
         //nEk := nAvgBuy
      ENDIF


      nMarg := _GetMinMargin(art->Matchcode)

      //IF Tr_getini(28)==9; Alert("Margin "+Str(nMarg)); ENDIF
      nVK := Max(cmpr->Preis*0.95,nEk/(1-nMarg))*art->VkPe

      IF lDbg
         Alert("Qty: "+LTrim(Str(cmpr->Menge))+";Buy price: "+LTrim(Str(nEK))+";Sales price: "+LTrim(Str(nVK)) )
      ENDIF

      IF nVk < nLast
         IF lDbg; Alert("Konkurrenz"+Str(cmpr->Preis*0.95)+" EK: "+Str(nEk)+" "+str(cmpr->Menge)+" VK "+Str(nVK)); ENDIF
         Aadd(aPriceTabs,{cmpr->Menge,nVk})
         nLast := nVk
      ENDIF
   ENDIF
   cmpr->(Rec_Lock())
   cmpr->LastReq := Date()
   cmpr->(dbUnLock())
   cmpr->(dbSkip())
ENDDO

IF lDbg
   Alert(ValToPrg(aPriceTabs))
ENDIF

ASort(aPriceTabs,,,{|x,y| x[1] < y[1] .OR. (x[1] == y[1] .AND. x[2] < y[2])})

IF Len(aPriceTabs) > 1
   nLast := Round(aPriceTabs[1,2],2)
   nX := 2
   DO WHILE .T.
      IF nLast <= Round(aPriceTabs[nX,2],2) .OR. aPriceTabs[nX,2] == 0
         HB_ADel(aPriceTabs,nX,.T.)
      ELSE
         nLast := Round(aPriceTabs[nX,2],2)
         nX++
      ENDIF
      IF nX > Len(aPriceTabs) .OR. Len(aPriceTabs) <= 1
         EXIT
      ENDIF
   ENDDO
ENDIF

RETURN aPriceTabs

#include 'X:\run\margin.prg'

STATIC FUNCTION __GetCallStack()
   LOCAL aStack := {}
   LOCAL nStack := 1  // Skip the GetCallStack() function in the result

   DO WHILE .NOT. Empty( ProcName(nStack) )
      AAdd( aStack, Upper(ProcName(nStack)) )
      nStack ++
   ENDDO

RETURN aStack
