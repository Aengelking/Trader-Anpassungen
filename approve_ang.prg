FUNCTION HOOK_APPROVE_ANG(nAngnr)

LOCAL oArtikel,aProducts := {}
LOCAL cSupplier,nEk,nVk,nMargin
LOCAL lDbg := .F. //Tr_Getini(28) == 9
LOCAL cDbg := ""
LOCAL nGewinn,lRet
LOCAL lPorto := .F.
LOCAL cText1 := "",nLevel := 3
LOCAL oExtra
LOCAL nMaxLZ := 12 //Maximale Rahmenlaufzeit
LOCAL nZins := 0.1 //Zinssatz fr Margenreduktion durch Zinskosten
LOCAL nMelde,nMarginDiff

NetUse("engkund","ku")

ang->(dbSetOrder( 1 ))
ang->(dbSeek( Str(nAngnr,6) ))

IF ang->Besda < StoD("20141006" )
//   RETURN .T.
ENDIF

DO WHILE ang->Angnr == nAngnr
   IF ang->VkPr != 0 .AND. ang->VkQty != 0 //not a text position
     oArtikel := Artikel():New(.F.)
     oArtikel:Load(ang->Artikelnr)

      IF Trim(oArtikel:Matchcode) $ {"PORTO","FREIGHT"}
         lPorto := .T.
      ENDIF

     nVk := ang->VkPr * Currate( ang->Money, "V" ) / ang->Pe

     IF oArtikel:Manufactur $ {12} //Elcom Mindermengenzuschlag
         nVK -= 60/ang->VkQty
     ENDIF

      IF oArtikel:Manufactur $ {12,16} //Elcom oder Signal 
         IF oArtikel:Gewicht == 0 //no weight, no prices
            cText1 += t(Trim(oArtikel:Matchcode)+" hat kein Gewicht")+";"
            nVK := 0                     
         ELSE         
            nVK -= Hook("get_supplier_ship_cost",{Pad(IF(oArtikel:Manufactur == 16,"SIGNAL","ELCOM"),8),oArtikel:Gewicht/1000*ang->VkQty})/ang->VkQty            
         ENDIF   
      ENDIF

     IF Tr_Getini(28) == 9
     // ALTD()
     ENDIF
     IF lDbg
         //Alert(DtoC(ang->Besda))
     ENDIF     
     nEk := oArtikel:GetBuyPriceForMargin(ang->VkQty,.T.,ang->Besda,AddWeeks(CWeek(ang->Besda),ang->Dterm),@cSupplier)
     IF Tr_Getini(28) == 9
        cDbg +=  "Buy price "+Trim(oArtikel:Matchcode)+": "+LTrim(Str(nEK))+" "+cSupplier+";"
     ENDIF

     nGewinn := ( nVk * ( 100 - ang->Rabatt ) / 100 ) - ( nEk * ( 100 -oArtikel:rabatt ) / 100 )
     nMargin := IF(nVk!=0,nGewinn/nVk,0)

     IF ang->LZ > nMaxLZ
        cText1 += Trim(oArtikel:Matchcode)+" hat eine Laufzeit von "+LTrim(Str(ang->LZ))+" Monaten;"
        nLevel := 1
     ENDIF

     IF ang->LZ > 0
         //Meldebestand kann im Auftrag nicht definiert werden, daher berechnen wir das anhand der Lieferzeit
         nMelde  := IF(oArtikel:LZ>0,oArtikel:LZ,12) / 4.35 * ang->VkQty / ang->LZ * 2 //Rechnerisch ausreichend fr doppelte Lieferzeit
         //Margenreduktion durch Zinskosten sch„tzen
         nMarginDiff := nZins * ang->LZ / 12 * nMelde/ang->VkQty  + nZins/24
         IF Tr_GetIni(28) == 9
            cDbg += "Meldebestand "+Trim(oArtikel:Matchcode)+": "+LTrim(Str(nMelde))+";Margenreduktion durch Zinskosten: "+LTrim(Str(nMarginDiff*100,6,2))+"%;"
         ENDIF
         nMargin -= nMarginDiff
     ELSE
         nMarginDiff := 0
     ENDIF

     IF lDbg
         Alert(oArtikel:Matchcode+";Lieferant: "+cSupplier+";"+"Menge: "+LTrim(Str(ang->VkQty))+";EK: "+LTrim(Str(nEk))+";"+"VK:"+LTrim(Str(nVk))+";"+"Gewinn:"+Ltrim(Str(nGewinn))+";Margin:"+LTrim(str(nMargin*100,6,2)))
     ENDIF

     Aadd(aProducts,{"ARTIKEL"=>oArtikel,"QTY"=>ang->VkQty,"GELQTY"=>0,"VKPR"=>ang->VkPr/ang->Pe,"MARGIN"=>nMargin,"KW"=>AddWeeks(Val(CalWeek(ang->Besda)),ang->Dterm),"SUPPLIER"=>cSupplier,"NEK"=>nEk,"FINCOST"=>nMarginDiff})
   ENDIF
   ang->(dbSkip())
ENDDO
ang->(dbSeek( Str(nAngnr,6) ))

IF ! Empty(cDbg)
   Alert(cDbg)
ENDIF

ku->(dbSetOrder( 1 ))
ku->(dbSeek( ang->Kundma+"K" ))

IF sk->(IsPrePay(ku->Skonto)) .AND. ! lPorto .AND. ! ku->Versandart $ {10,44,46,49,56}
   oExtra := ku->(ExtraData():New(ku->Nummer))
ENDIF

lRet := Hook("approve_auf_ang",{aProducts,cText1,nLevel,ang->Kundma,ang->Besda,ang->Money,.F.})

RETURN lRet

#include 'x:\run\getupsimportcost.prg'