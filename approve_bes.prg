FUNCTION HOOK_APPROVE_BES(nBesnr)

#define DEBUG Tr_Getini(28) == 9

LOCAL nLevel := 4
LOCAL aLevels := { {9},{37,45},{57},{28,33,41,54,58,63} }
LOCAL cText := "",cBaseText
LOCAL aUsers
LOCAL oArt
LOCAL nTotal :=0,nTotVerp := 0
LOCAL nPosnr,lHasFolge
LOCAL nPrice
LOCAL nOver,nThai
LOCAL nQty
LOCAL nPosVal,aKW,nMindest,hReqInc,nX
LOCAL aLowPrice
LOCAL nCur

IF  Date() >= GetValue("HOLIDAY-AMOS-START") .AND. Date() <= GetValue("HOLIDAY-AMOS-END") //Amos holiday
   Aadd(aLevels[1],45)
ENDIF

IF Trim(bes->Liefma) == "BULGIN" //tempor„r bis wir eine Bestellung ber 4000 GBP zusammmen haben
   //cText += "Rcksendung durchfhren"
   //nLevel := 1
ENDIF

NetUse("engauf","auf")
NetUse("folgeart","fol")

bes->(dbSetOrder( 1 ))
art->(dbSetOrder( 2 ))

bes->(dbSeek( Str(nBesnr,6) ))
DO WHILE bes->Besnr == nBesnr .AND. ! bes->(Eof())  //take all positions back out of the unapproved state, so stock is calculated correctly
   IF bes->BeStat >= 6
      bes->(Rec_Lock(0))
      bes->BeStat -= 6
      bes->(dbUnLock())
   ENDIF
   bes->(dbSkip())
ENDDO

bes->(dbSeek( Str(nBesnr,6) ))

//IF Tr_Getini(28) == 9;Alert("HERE");ENDIF

DO WHILE bes->Besnr == nBesnr .AND. ! bes->(Eof())
   IF bes->ContrNo == 0  //abrufe  müssen nicht überprüft werden (zumindest solange wir keine Termine prüfen)
      oArt := Artikel():New()
      oArt:Load(bes->Artikelnr)

      cBaseText := "#"+LTrim(Str(bes->Posnr))+" "+Trim(oArt:Matchcode)

      //check to see if it has folgepositionen, if it is not stockable
      lHasFolge := .F.
      IF ! oArt:Lagerart
         nPosnr := bes->Posnr
         bes->(dbSkip(1))
         IF bes->Besnr == nBesnr .AND. bes->FolgeTo == nPosnr
            lHasFolge := .T.
         ENDIF
         bes->(dbSkip(-1))
         IF ! lHasFolge .AND. ! AT("WA",bes->Grund) == 1
            IF Trim(bes->Matchcode) == "PRšFBERICHT" .AND. bes->EKpr < 100
               nLevel := 3
            ELSEIF Trim(bes->Matchcode) == "WERKZEUGKOSTEN"
               cText := cBaseText+" beim Lieferanten als @ bestellen"
               nLevel := 1
            ELSE
               nLevel := 1
               cText := cBaseText+" Artikel nicht lagerf„hig"
            ENDIF
            
            
         ENDIF
      ENDIF

      IF (oArt:Lagerart .OR. lHasFolge) .AND. bes->FolgeTo == 0 .AND. (bes->BeStat < 3 /*.OR. bes->bestat >= 5*/) .AND. bes->BeQty > 0 .AND. (bes->EkPr != 0 .OR. bes->BeQty > 3)
         nPrice  := IF(bes->ekpr != 0,bes->ekpr-(bes->ekpr*bes->rabatt/100),0)/bes->pe*Currate(bes->Money,"E")
         nPosVal := Round( If(bes->bestat==3,bes->gelqty,bes->beqty)*nPrice ,2)
         nTotal += nPosVal
         IF Trim(oArt:Type) == "VERP"
            nTotVerp += nPosVal
         ENDIF

         IF bes->BeQty > 1000 .AND. nPosVal >= 200
            aLowPrice := oArt:GetBuyPrice(bes->Liefma,9999999)
            IF aLowPrice["qty"]*IF(aLowPrice["qty"]<5000,2,IF(aLowPrice["qty"]<10000,1.5,1.3)) < bes->BeQty .AND. nPrice >= aLowPrice["price"]/aLowPrice["unit"]
               cText += cBaseText+": kein Einkaufspreis fr "+LTrim(Transform(bes->BeQty,oArt:cPicture))+" "+Trim(oArt:Me)+" vorhanden;"
               nLevel := 1
            ENDIF
         ENDIF

         aKW := GetKwQty(oArt:Artikelnr)
         nOver := ATail(aKW)[6]

         nThai := LagGetStock(oArt:Artikelnr,4,22221)
         nOver -= nThai //remove the stock in Thailand

         
         nMindest := _GetMindestMax(oArt) //IF(oArt:LZ==0,12,oArt:LZ)*oArt:Mindest/4.5*2         
         IF Trim(oArt:Type) == "RHB"
            IF nOver > nMindest .AND. nPrice*nOver <= 50 //Überbestellung nur 50€
               oArt:MaxBestand := Max(oArt:MaxBestand,nOver+nThai)
               oArt:Save()
            ELSEIF nOver-nMindest > 5
               //Alert(Str( nPrice*nOver ))
               IF nPrice*nOver <= 150
                  nLevel := 3
               ELSEIF nPrice*nOver <= 250
                  nLevel := 2
               ELSE
                  nLevel := 1
               ENDIF
               nQty   := nOver-nMindest
               cText  += cBaseText+" "+LTrim(Transform(nQty,Me(oArt:Me)))+" "+oArt:Me+" zu viel bestellt;"
            ENDIF
         ELSEIF nOver > 3 .AND. Trim(oArt:Type) != "VERP" //3 Muster drüfen verbleiben, bei Verpackungsmaterial wird nur der Gesamtwert betrachtet            
            hReqInc := GetProductRequirementAndIncoming(bes->artikelnr)
            IF nOver > nMindest .AND. (hReqInc["cust_count"] < 2 .OR. hReqInc["avgrequirement"] < nOver)
               //Alert("Here "+bes->Matchcode+Str(nPrice*nOver)+Str(nOver))
               IF nPrice*(nOver-nMindest) <= 150
                  nLevel := 3
               ELSEIF nPrice*(nOver-nMindest) <= 150
                  nLevel := 2
               ELSE
                  nLevel := 1
               ENDIF
               nQty := nOver-nMindest
               cText += cBaseText+" "+LTrim(Transform(nQty,Me(oArt:Me)))+" "+oArt:Me+" zu viel bestellt;"
               //+IF(DEBUG,Str(nQty)+Str(nOver)+Str(nMindest),"")

               IF Tr_Getini(28) == 9
//                  cText += LTrim(Transform(oArt:Bestand,Me(oArt:Me)))+"+"+LTrim(Transform(hReqInc["income"],Me(oArt:Me)))+"+"+LTrim(Transform(IF(bes->BeStat >3,bes->BeQty-bes->GelQty,0),Me(oArt:Me)))+"-"+LTrim(Transform(hReqInc["requirement"],Me(oArt:Me)))
               ENDIF
   
            ELSE
      //         nLevel := 2
               //nQty := bes->BeQty
            ENDIF
      //      cText += cBaseText+" "+LTrim(Transform(nQty,Me(oArt:Me)))+" "+oArt:Me+" zu viel bestellt;"
         ENDIF
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

IF nTotVerp > 1000
   cText += t("Bestellwert (Verpackung) über 1000 EUR;")
   nLevel := 3
ENDIF
IF nTotal > 50000
   cText += t("Bestellwert über 50.000 EUR ("+LTrim(Str(nTotal))+");")
   nLevel := 1
ELSEIF nTotal > 20000
   cText += t("Bestellwert über 20.000 EUR;")
   nLevel := 1
ELSEIF nTotal > 100
   nLevel := 3 //Level 4 k”nnen nur Musterbestellunge ausl”sen (Verkauf)
ENDIF

aUsers := {}
FOR nX := nLevel TO 1 STEP -1
   AEval(aLevels[nX],{|x| Aadd(aUsers,x) })
NEXT
RETURN {cText,aUsers}

STATIC Function _GetMindestMax(oArt)
   LOCAL nMindest := Round(IF(oArt:LZ==0,12,oArt:LZ)*oArt:Mindest/4.5*2,GetMeDecimals( oArt:Me ))
   LOCAL nAufMin  := 0
   LOCAL oFol

   nAufMin := _GetAufMindest(oArt)
   fol->(dbSetOrder( 2 ))
   fol->(dbSeek( Str(oArt:Artikelnr,6) ))
   DO WHILE fol->FolgeArt == oArt:Artikelnr
      oFol := Artikel():New()
      oFol:Load(fol->Artikelnr)
      nAufMin += _GetAufMindest(oFol)
      fol->(dbSkip())
   ENDDO
   nMindest := Max(nMindest,nAufMin)
RETURN nMindest

STATIC Function _GetAufMindest(oArt)
   LOCAL nMindest := 0
   auf->(dbSetOrder( 3 ))
   auf->(dbSeek( oArt:Matchcode, .T. ))

   DO WHILE auf->matchcode == oArt:Matchcode .AND. auf->Bestat < 3
      IF Right(Str(auf->DTerm,4),2) == "99"
         nMindest += Min(IF(oArt:LZ==0,12,oArt:LZ)*auf->MeldStock/4.5*2,auf->VkQty)
      ENDIF
      auf->(dbSkip())
   ENDDO
RETURN nMindest