FUNC RUN_GESSMANN_PREISE
   LOCAL cKunde := Pad("GESSMANN",8)
   LOCAL hParts := {=>},aPart,cFilter
   LOCAL bAddPart,nPriceQty
   LOCAL aData := {},nQty,nDec

   NetUse("englsre","re")
   NetUse("engauf","auf")
   NetUse("artkund","aku")
   NetUse("artikel","art")

   CLS 

   bAddPart := {|nArtikelnr|
      IF ! nArtikelnr $ hParts
         hParts[nArtikelnr] := {"SHIPPED"=>{0,0},"SOLD"=>{0,0},"PRICES"=>{=>}}
      ENDIF
      RETURN NIL
   }

   cFilter := 'reposnr != 0 .AND. ! folge .AND. rechdat >= StoD("'+Str(Year(Date())-2,4)+'0101") .AND. rechdat <= StoD("'+Str(Year(Date())-1,4)+'1231")'
   
   re->(dbSetFilter( {|| re->(&(cFilter)) },cFilter))
   re->(dbSeek( cKunde ))
   
   
   DO WHILE re->Kunde == cKunde
      Eval(bAddPart,re->Artikelnr)
        
      hParts[re->Artikelnr]:SHIPPED[Year(Date())-Year(re->Rechdat)] += re->AoQty
      re->(dbSkip())
   ENDDO

   re->(dbClearFilter())

   cFilter := 'contrpos == 0 .AND. folgeto == 0 .AND. besda >= StoD("'+Str(Year(Date())-2,4)+'0101") .AND. besda <= StoD("'+Str(Year(Date())-1,4)+'1231")'

   auf->(dbSetOrder( 11 )) //kundma+Str(abnr,6)
   auf->(dbSetFilter( {|| auf->(&(cFilter)) },cFilter))
   auf->(dbSeek( cKunde ))

   DO WHILE auf->Kundma == cKunde .AND. ! auf->(EOF())
      Eval(bAddPart,auf->Artikelnr)
        
      nQty := Max(auf->VkQty,auf->ContrQty)

      hParts[auf->Artikelnr]:Sold[Year(Date())-Year(auf->Besda)] += nQty

      IF ! auf->VkPr/auf->Pe $ hParts[auf->Artikelnr]:Prices .OR. auf->VkQty < hParts[auf->Artikelnr]:Prices[auf->VkPr/auf->Pe]
         hParts[auf->Artikelnr]:Prices[auf->VkPr/auf->Pe] := nQty
      ENDIF

      auf->(dbSkip())
   ENDDO


   art->(dbSetOrder( 2 ))

   Aadd(aData,{"Unsere Artikelnr","Ihre Teilenummer","Geliefert "+Str(Year(Date())-2,4),"Geliefert "+Str(Year(Date())-1,4),"Bestellt "+Str(Year(Date())-2,4),"Bestellt "+Str(Year(Date())-1,4)})

   FOR EACH aPart IN hParts      
      art->(dbSeek( Str(aPart:__eNumKey() ,6) ))
      nDec := GetMeDecimals(art->Me)
      Aadd(aData,{Trim(art->Matchcode),IF(aku->(dbSeek( cKunde+Str(art->Artikelnr,6) )),Trim(aku->Artlief),""),Round(aPart:Shipped[2],nDec),Round(aPart:Shipped[1],nDec),Round(aPart:Sold[2],nDec),Round(aPart:Sold[1],nDec)})
      
      FOR EACH nPriceQty IN aPart:Prices
         Aadd(Atail(aData),nPriceQty:__eNumKey())
         Aadd(Atail(aData),nPriceQty)
      NEXT
   NEXT
   SaveAsCSVInterface(aData)
   //Sinkey(0)

   