FUNC RUN_GESSMANN_PREISE
   LOCAL cKunde := Pad("GESSMANN",8)
   LOCAL hParts := {=>},aPart,cFilter

   NetUse("englsre","re")
   NetUse("engauf","auf")
   NetUse("artkund","aku")

   cFilter := 'reposnr != 0 .AND. rechdat >= StoD("'+Str(Year(Date())-2)+'"0101") .AND. rechdat <= StoD("'+Str(Year(Date())-1)+'"1231)'
   re->(dbSetFilter( {|| re->(&(cFilter)) },cFilter))
   re->(dbSeek( cKunde ))
   
   //{"Unsere Artikelnr"=>re->Matchcode,"Ihre Teilenummer"=>IF(aku->Found,aku->Artlief,""),"Geliefert"=>0,"AUFMENGE"=>0}

   DO WHILE re->Kunde == cKunde
      IF re->Artikelnr $ hParts
        hParts[re->Artikelnr] := {"SHIPPED"=>{0,0},"SOLD"=>0}
      ENDIF
      
      hParts[re->Artikelnr]:Shipped[Year(re->Rechdat)-Year(Date())] += re->AoQty

      re->(dbSkip())
   ENDDO

   FOR EACH aPart IN hParts
      art->(dbSeek( Str(aPart:__eNumKey() ,6) ))
      aku->(dbSeek( cKunde+Str(art->Artikelnr,6) ))
      ? art->Matchcode,IF(aku->Found,aku->Artlief,""),aPart:Shipped,aPart:Sold
   NEXT
   Sinkey(0)

   re->(dbClearFilter())