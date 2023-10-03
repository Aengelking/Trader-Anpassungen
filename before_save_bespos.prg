FUNCTION HOOK_BEFORE_SAVE_BESPOS( oBesPos )

LOCAL nPrice,nPe,lCheap,lStock,nEk,nPerc
LOCAL cTextFile,cText,nQty
LOCAL oAddress

MEMVAR mcNoBesPos 
PUBLIC mcNoBesPos := ""

IF ! oBesPos:lNew
   RETURN .T.
ENDIF

NetUse("buyprice","bpr")
NetUse("artikel","art")
NetUse("liefstock","lsto")


/*IF Trim(art->Matchcode) == "PX0686" .AND. Trim(oBesPos:oBestellung:Liefma) != "RS"
   TR_MsgBox(t("Diesen Artikel bei RS anfragen/bestellen - ist dort wahrscheinlich günstiger!"))
   RETURN .F.
ENDIF

IF Trim(art->Matchcode) == "PX0833" .AND. Trim(oBesPos:oBestellung:Liefma) != "REICHELT"
   TR_MsgBox("Diesen Artikel bei Reichelt bestellen - ist am gnstigsten.")
ENDIF*/

/*IF Trim(art->Matchcode) $ "PX0910 SA3324 PX0960 SA3325 PX0920 PX0980" .AND. ! GetConfigValue("BATCHMODE")
   IF Tr_MsgBox(t("Bitte prüfen ob es nicht sinnvoller wäre PX09/07_SET zu bestellen"),,{"abbrechen",t("trotzdem einfügen")}) != 2
      RETURN .F.
   ENDIF
ENDIF*/

IF Empty(art->Kncode) .AND. art->Lagerart
   oAddress := Adresse():New(.F.)
   oAddress:LoadMatchcode(oBesPos:oBestellung:Liefma,"L")
   IF oAddress:CountryIso != "DE" .AND. IsCountryInEU(oAddress:CountryIso) 
      IF ! GetConfigValue("BATCHMODE")
         Tr_MsgBox("Bitte Zolltarifnummer hinterlegen.")
         RETURN .F.
      ELSE
         SendMail({{"amos.engelking@engelking.de","Amos"}},"Zolltarifnummer bei Artikel "+Trim(art->Matchcode)+" hinterlegen")
      ENDIF
   ENDIF
ENDIF


IF oBesPos:oArtikel:Manufactur == 1 .AND. oBesPos:BeQty > 0 .AND. oBesPos:WTerm <= Val(CalWeek(Date())) .AND. ! GetConfigValue("BATCHMODE") //Bulgin, Bestellmenge größer null und auf sofort bestellt

   nPrice := nPe := 0
   lCheap := .F.
   lStock := .F.
   cText := ""

   IF Trim(oBesPos:oBestellung:Liefma) == "BULGIN"  //BULGIN
      GetBuyPrice( Pad("WALDOM",8), oBesPos:Artikelnr, oBesPos:BeQty, @nPrice, @nPE )
      IF nPrice != 0
         nEk := oBesPos:EkPr/oBesPos:Pe*Currate("P","E")
         nPerc := ABS((nPrice/nPe-nEk)/nPrice/nPe*100)
         lCheap := nPrice/nPe < nEk
         cText += "ist "+LTrim(Str(nPerc,5,2))+"% "+IF(lCheap,t("günstiger"),"teurer")
      ENDIF
   
      IF lsto->(dbSeek( Pad("WALDOM",8)+Str(oBesPos:Artikelnr,6) ))
         IF lsto->Stock > oBesPos:BeQty
            IF ! Empty(cText)
               IF lCheap
                  cText += " und hat "
               ELSE
                  cText += " hat jedoch "
               ENDIF
            ELSE
               cText += "hat "
            ENDIF
            cText += "ausreichend Lagerbestand."
            IF nPrice == 0
               cText += " Die Menge ist jedoch unter MOQ."
            ENDIF
            lStock := .T.
         ELSEIF lsto->DelQty >= oBesPos:BeQty
            IF ! Empty(cText)
               IF lCheap
                  cText += " und wird "
               ELSE
                  cText += " wird jedoch "
               ENDIF
            ENDIF
            cText += t("diese Menge in Kürze verfügbar haben.")
            lStock := .T.
         ENDIF
         IF lStock .OR. lCheap
            IF TR_MsgBox("WALDOM "+cText,,{"abrechen",t("trotzdem einfügen")}) != 2
               RETURN .F.
            ENDIF
         ENDIF
      ENDIF
   ELSEIF Trim(oBesPos:oBestellung:Liefma) == "WALDOM"
      GetBuyPrice( Pad("BULGIN",8), oBesPos:Artikelnr, oBesPos:BeQty, @nPrice, @nPE )
      IF nPrice != 0
         nEk := oBesPos:EkPr/oBesPos:Pe/Currate("P","E")
         nPerc := ABS((nPrice/nPe-nEk)/nPrice/nPe*100)
         IF nPrice/nPe < nEk
            IF TR_MsgBox("BULGIN ist "+LTrim(Str(nPerc,5,2))+"% "+t("günstiger"),,{"abrechen",t("trotzdem einfügen")}) != 2
               RETURN .F.
            ENDIF
         ENDIF
      ENDIF
      IF oBesPos:EkPr/oBesPos:Pe*oBesPos:BeQty < 25
         TR_MsgBox(t("Mindesbestellwert unterschritten (EUR 25)"))
         RETURN .F.
      ENDIF
   ENDIF
ENDIF

IF oBesPos:oArtikel:Manufactur == 11 //Techno
   nQty := QtyProducible(oBesPos:oArtikel:Artikelnr,,.T.,.T.)
   IF nQty > 0
      IF GetConfigValue("BATCHMODE")
         mcNoBesPos := Transform(nQty,oBesPos:oArtikel:cPicture)+" "+oBesPos:oArtikel:Me+" k”nnen gefertigt werden."
         RETURN .F.
      ELSE
         Tr_MsgBox(Transform(nQty,oBesPos:oArtikel:cPicture)+" "+oBesPos:oArtikel:Me+" k”nnen gefertigt werden.")
      ENDIF
   ENDIF
ENDIF

IF Trim(oBesPos:oBestellung:Liefma) $ {"WHTECH","SELT"} .AND. oBesPos:BeQty == 1
   IF GetConfigValue("BATCHMODE") 
      SendMail({{"amos.engelking@engelking.de","Amos"}},"Erstmuster fr Artikel "+Trim(art->Matchcode)+" bestellen?")   
   ELSEIF Tr_MsgBox("Wirklich nur 1 Stck? Kein Erstmuster notwendig?",,{"Nein","Ja"}) != 2
      RETURN .F.
   ENDIF
ENDIF
   

/*IF AScan({9,37},TR_Getini(28)) == 0
   aAvail := GetKwQty(oBesPos:oArtikel:Artikelnr)

   IF oBesPos:ContrNo == 0 .AND. ATail(aAvail)[6] > 0 //verfügbar
      Alert(t("Bereits genügend bestellt"))
      RETURN .F.
   ELSEIF GetKwStock(,AddWeeks(Min(oBesPos:WTerm,oBesPos:Lterm),oBesPos:ShipTime+2),aAvail) >= 0
      Alert("Ausreichend Bestand zu diesem Termin")
      RETURN .F.
   //ELSEIF GetKwStock(,AddWeeks(Min(oBesPos:WTerm,oBesPos:Lterm),2),aAvail) >= 0

   ENDIF
ENDIF*/
   #define CRLF CHr(13)+Chr(10)
   NetUse("zeichpruef","zeipr")
   IF ! Empty(oBesPos:oArtikel:Zeichnung) .AND. Trim(oBesPos:Liefma) == "WHTECH".AND. (! zeipr->(dbSeek(oBesPos:oArtikel:Zeichnung+oBesPos:oArtikel:ZeichIndex+IF(oBesPos:oArtikel:KuZeichnun,"Y","N"))) .OR. zeipr->Datum < StoD("20230914"))
      cText := "Hi Heike,"+CRLF+CRLF+"Bitte prfe ob der folgenden Zeichnung die Kabel-/Litzenhersteller bestimmt sind"+CRLF
      cText += "Zeichnung: "+oBesPos:oArtikel:Zeichnung+CRLF
      cText += "Artikel: "+oBesPos:oArtikel:Matchcode+" (eventuell noch weitere!)"+CRLF
      
      SendMail({{"heike.scheckenburger@engelking.de","Heike"}},"Zeichnung prfen",cText)
      IF zeipr->(EOF())
         zeipr->(Add_Rec(0))
         zeipr->Zeichnung := oBesPos:oArtikel:Zeichnung
         zeipr->ZeichIndex := oBesPos:oArtikel:ZeichIndex
         zeipr->KuZeichnun := oBesPos:oArtikel:KuZeichnun
      ELSE
         zeipr->(Rec_Lock())
      ENDIF
      zeipr->Datum := Date()
      zeipr->(dbUnLock())

   ENDIF


RETURN .T.

#include 'x:\run\stock_use.prg'