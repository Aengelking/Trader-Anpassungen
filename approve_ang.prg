FUNCTION HOOK_APPROVE_ANG(nAngnr)

LOCAL oArtikel,aProducts := {}
LOCAL cSupplier,nEk,nVk,nMargin
LOCAL lDbg := .F. //Tr_Getini(28) == 9
LOCAL cDbg := ""
LOCAL nGewinn,lRet
LOCAL lPorto := .F.
LOCAL cText1 := "",nLevel := 3
LOCAL oExtra

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
     IF Tr_Getini(28) == 9
//      ALTD()
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

     IF lDbg
         Alert(oArtikel:Matchcode+";Lieferant: "+cSupplier+";"+"Menge: "+LTrim(Str(ang->VkQty))+";EK: "+LTrim(Str(nEk))+";"+"Gewinn:"+Ltrim(Str(nGewinn))+";Margin:"+LTrim(str(nMargin*100,6,2)))
     ENDIF

     Aadd(aProducts,{"ARTIKEL"=>oArtikel,"QTY"=>ang->VkQty,"GELQTY"=>0,"VKPR"=>ang->VkPr/ang->Pe,"MARGIN"=>nMargin,"KW"=>AddWeeks(Val(CalWeek(ang->Besda)),ang->Dterm),"SUPPLIER"=>cSupplier,"NEK"=>nEk})
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
   IF oExtra:OnlineKauf
      cText1 += t("Kein Porto berechnet ")+";"
      IF nLevel > 2
         nLevel := 2
      ENDIF
   ENDIF
ENDIF

lRet := Hook("approve_auf_ang",{aProducts,cText1,nLevel,ang->Kundma,ang->Besda,ang->Money,.F.})

RETURN lRet

STATIC Function AngMargin(oArtikel)
   LOCAL nVk := ang->VkPr * Currate( ang->Money, "V" ) / ang->Pe
   LOCAL nEk,nGewinn

   nEk := oArtikel:GetBuyPriceForMargin(ang->VkQty,.T.,ang->Besda)

   nGewinn := ( nVk * ( 100 - ang->Rabatt ) / 100 ) - ( nEk * ( 100 -oArtikel:rabatt ) / 100 )
   IF Tr_Getini(28) == 9
      Alert("EK: "+LTrim(Str(nEk))+";"+"Gewinn:"+Ltrim(Str(nGewinn)))
      //Alert(Trim(oArtikel:Matchcode)+";"+Str(GetKwStock(ang->Artikelnr,AddWeeks(CWeek(ang->Besda),ang->Dterm)))+";EK: "+Ltrim(Str(nEk))+";Margin: "+Str(nGewinn/nVk,5,2))
   ENDIF
RETURN IF(nVk!=0,nGewinn/nVk,0)