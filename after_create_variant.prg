FUNCTION HOOK_AFTER_CERATE_VARIANT(oArtikel)
   LOCAL cArtLief
   LOCAL cText
   LOCAL oUsr := SystemUser()
   LOCAL nPoles,cSeries,oExtra

   NetUse("buyer","buy")
   
   cText := "Hallo,<br><br>folgender Varianten Artikel wurde von "+Trim(oUsr:Buyer)+" angelegt:<br><br>"
   cText += 'Matchcode:  <a href="trader: -F BrowseArtikel('+"'"+Trim(oArtikel:Matchcode)+"'"+')">'+oArtikel:Matchcode+"</a><br>"
   cText += "Artikelnr.: "+LTrim(Str(oArtikel:Artikelnr))   
   
   IF Left(oArtikel:Matchcode,2) $ {"CM","CI"}
      NetUse("artlief","ali")
      NetUse("buyprice","bpr")
      cArtLief := OnpowPartno()
      IF ! Empty(cArtLief)         
         ali->(Add_Rec(0))
         ali->Kunde := "ONPOW"
         ali->Matchcode := oArtikel:Matchcode
         ali->Artikelnr := oArtikel:Artikelnr
         ali->Artlief   := cArtlief
         ali->Priority  := 1
         ali->(dbUnLock())

         MBaseRun(Trim(Tr_getini(1))+"\run\onpow_prices",{.T.}) //first parameter needs to be .T. to only set prices on this part

         cText += "<br>Hersteller-Artikel: "+cArtlief         

         bpr->(dbSetOrder( 2 ))
         IF ! bpr->(dbSeek(ali->Kunde+Str(ali->Artikelnr,6))) .OR. bpr->EndDate < Date()
            cText += "<br>Preise fehlen!"
         ENDIF 

      ENDIF
   ELSEIF Left(oArtikel:Matchcode,2) == "SZ" //Signal Artikel auf Varianten Basis
      nPoles := Val(Substr(oArtikel:Matchcode,7,2))
      cSeries := Substr(oArtikel:Matchcode,3,2)
      IF (cSeries == "08" .AND. nPoles <= 6) .OR.;
         (cSeries == "12" .AND. nPoles <= 5)   
         oExtra := art->(ExtraData():New(art->Artikelnr))
         oExtra:APPR_CE := .T.
         oExtra:Save()
      ENDIF
   ENDIF
   cText += "<br>UL prÅfen!"
   cText += "<br>ELEKTROG prÅfen!"
   //SendMail(aTo,cSubject,cMessage,aAttachement,lIntern,nPriority,lHtml,cFrom)
   Sendmail({{"yannick.matthaeus@engelking.de","Yannick"}},"Variant wurde angelegt "+Trim(oArtikel:Matchcode),cText,,,,.T.)
RETURN NIL

#include 'X:\run\onpow_part_no.prg'