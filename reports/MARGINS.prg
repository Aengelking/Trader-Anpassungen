PROC RUN_REPORT_MARGINS
   LOCAL dStart := SToD("20240101")
   LOCAL dEnd   := EoY(dStart)
   LOCAL oArt
   LOCAL aList := {}
   LOCAL nVK,nEK
   LOCAL hCache := {=>},cKey

   Head(t("Margin für Lieferpositionen ausgeben"))

   NetUse("englsre","re")
   NetUse("manufact","man")

   re->(dbSetOrder(9))  
   
   
   re->(dbSetFilter({|| re->reposnr!=0 .AND. re->Preis > 0 },"reposnr > 0 .AND. Preis > 0 "))
   re->(dbSeek(Dtos(dStart),.T.))

   Aadd(aList,{"Rechnung","Position","Datum","Kunde","Artikel","Hersteller","Menge","VK","EK","Umsatz","Marge","Marge %"})
   DO WHILE ! re->(EOF()) .AND. re->Rechdat <= dEnd .AND. Inkey() != 27
      @ 24,00 SAY re->Rechnr
      oArt := Artikel():new()
      oArt:Load(re->Artikelnr)
      IF Left(oArt:Matchcode,1) != "@" .AND. ! Trim(oArt:Matchcode) $ {"FREIGHT","PORTO"} .AND. re->AoQty > 0
         oArt:Load(re->Artikelnr,1)
         man->(dbSeek( Str(oArt:Manufactur,5) ))
         nVK := re->Preis/IF(re->Pe==0,1,re->Pe)*(100-re->Rabatt)/100
         cKey := Str(re->Artikelnr,6)+DtoS(re->Rechdat)
         IF HHasKey(hCache,cKey)
            nEK := hCache[cKey]
         ELSE
            nEK := oArt:GetAvgBuyPrice(re->Rechdat)
            hCache[cKey] := nEK
         ENDIF
         Aadd(aList,{re->Rechnr,re->Reposnr,re->Rechdat,re->Kunde,Trim(re->Matchcode),Trim(man->Short),re->AoQty,nVk,nEk,"=H"+LTrim(Str(Len(aList)+1))+"*G"+Ltrim(Str(Len(aList)+1)),"=(H"+LTrim(Str(Len(aList)+1))+"-I"+LTrim(Str(Len(aList)+1))+")*G"+Ltrim(Str(Len(aList)+1)),"=(H"+LTrim(Str(Len(aList)+1))+"-I"+LTrim(Str(Len(aList)+1))+")*100/H"+LTrim(Str(Len(aList)+1))})
      ENDIF
      re->(dbSkip())
   ENDDO

   re->(dbClearFilter())

   SaveToOO_Interface(aList,,"XLSX")
   

