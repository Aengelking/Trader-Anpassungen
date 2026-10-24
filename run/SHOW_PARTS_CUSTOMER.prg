#include 'inkey.ch'

PROC RUN_SHOW_PARTS_CUSTOMER()
   LOCAL getlist := {}
   LOCAL cKSMatch := Space(25)
   LOCAL oArtikel
   LOCAL oArtBrowse
   LOCAL oArtFilter
   LOCAL nTop := 6
   LOCAL nLeft := 03
   LOCAL nRight := 162
   LOCAL bGetFreigabe := {||
      LOCAL cText
      ppf->(dbSetOrder( 1 ))
      ppf->(dbSetFilter( {|| ppf->Freigabe .AND. ! ppf->Sonderfrei  },"Freigabe .AND. ! Sonderfrei" ))
      IF ppf->(dbSeek( Str(art->Artikelnr,6)+art->Zeichnung+art->ZeichIndex ))
         cText := "abgeschlossen"
      ELSE
         cText := "OFFEN        "
      ENDIF
      ppf->(dbClearFilter())
      RETURN cText
   }

   NetUse("artikel","art")
   NetUse("artlief","ali")
   NetUse("parts","part")
   NetUse("ppf","ppf")

   Head("Alle Artikelfreigaben prfen")

   @ 01,00 SAY "Matchcode beginnt mit" GET cKSMatch
   ATail( getlist ):Reader := {| oGet, oGetlist, oMenu, oGetMsg| SwapReader( oGet, oGetList, oMenu, oGetMsg ) }
   READ
   
   IF LastKey() == 27
      RETURN
   ENDIF

   art->(dbSeek( cKSMatch ,.T. ))

   oArtBrowse := art->(TBrowseTr():New(nTop+1,nLeft+83,nTop+17,nRight))
   oArtBrowse:OneColumn := .T.
   oArtBrowse:lBox := .F.

   oArtBrowse:cFor := "! obsolete"

   oArtBrowse:WhileBlock := {|| AT(Trim(cKSMatch),art->Matchcode) == 1 }
   oArtBrowse:NewColumn("Matchcode",{|| art->Matchcode })
   oArtBrowse:NewColumn("Freigabe",bGetFreigabe)
   oArtBrowse:AddKey(K_ESC,{||.F.})
   oArtBrowse:AddKey(K_SPACE,{||DispInfo("TRD_01"),.T.}, "Infos anzeigen")
   oArtBrowse:AddKey(K_F11,{||
      IF oArtFilter == NIL
         oArtFilter := InteractiveFilter():New(nTop+18,nLeft+83,10,,"ARTIKEL")
         oArtFilter:AddValue("Matchcode",'Upper(matchcode)',Space(25))
         oArtFilter:AddValue("Artikel","Upper(artikel)",Space(35),"@!S25")
      ENDIF
      oArtFilter:Dialog()
      RETURN .T.
   })
   oArtBrowse:AddKey(K_F10 ,{||
      LOCAL hFields := {;
         "Artikelnummer"=>{|| art->Artikelnr },;
         "Matchcode"=>{|| art->Matchcode  },;
         "Beschreibung"=>{|| art->Artikel },;
         "Freigabe"=>bGetFreigabe,;
         "Zeichnung"=>{|| art->Zeichnung },;
         "Zeichnungsindex"=>{|| art->ZeichIndex },;
         "VPE"=>{|| art->VPE },;
         "Gewicht"=>{|| art->Gewicht },;
         "Ursprungsland"=>{|| art->Ursprung },;
         "Zolltarifnummer"=>{|| art->KnCode };
      }

      Hook("before_export_artikel",{hFields})

      oArtBrowse:SaveAsCSV(hFields)
      RETURN .T.
   },"Daten exportieren")

   oArtBrowse:EventLoop()
   RETURN

   DO WHILE AT(Trim(cKSMatch),art->Matchcode) == 1
      ? art->Matchcode,art->Zeichnung
      oArtikel := Artikel():New()
      oArtikel:Load(art->Artikelnr)
      
      ali->(dbSetOrder( 4 ))

      /*IF oArtikel:IsManufactured //in this case we need to get the "Lohn" position of the parts list
         part->(dbSetOrder( 1 ))
      IF part->(dbSeek( Str(art->Artikelnr,6)+Str(-1,4) )) //found "Lohn" position
         oArt := Artikel():New()
         oArt:Load(part->Partart)
         lExtern := .T.
      ENDIF
   ELSE
      oArt := oArtikel
      lExtern := .T.
   ENDIF
   IF lExtern .AND. oArt:LagerArt .AND. ! ali->(dbSeek( Str(oArt:Artikelnr,6) )) 
      ?? " Kein Lieferant"
   ENDIF*/
   IF ! Empty(oArtikel:Zeichnung) //Freigabe prfen  
      ppf->(dbSetOrder( 1 ))
      ppf->(dbSetFilter( {|| ppf->Freigabe .AND. ! ppf->Sonderfrei  },"Freigabe .AND. ! Sonderfrei" ))
      IF ppf->(dbSeek( Str(art->Artikelnr,6)+art->Zeichnung+art->ZeichIndex ))
         ?? " abgeschlossen"
      ELSE
         ?? " OFFEN"
      ENDIF
      ppf->(dbClearFilter())
      
   
         //hReq := GetProductRequirementAndIncoming(oArtikel:Artikelnr)   
         /*lBes := .F.
         nMaxQty := 0

         IF ! lExtern
            Eval(bGetFreigabe,0)
         ELSE
            ali->(dbSeek( Str(oArt:Artikelnr,6) )) 
            DO WHILE ali->Artikelnr == oArt:Artikelnr 
               oLief := Adresse():New()
               oLief:LoadMatchcode(ali->Kunde,"L")
               Eval(bGetFreigabe,oLief:Nummer)
               
               ali->(dbSkip())
            ENDDO
         ENDIF
      
         IF ! lBes //.OR. (nMaxQty > 0 .AND. nMaxQty+hReq["income"] < oAufPos:VkQty-IF(oAufpos:Bestat<3,oAufPos:GetField("VkQty",.T.),0)+hReq["requirement"])
            ?? " Freigabe nicht ausreichend"
         ELSEIF nMaxQty > 0
            ?? " Maximale Menge "+Transform(nMaxQty,oArtikel:cPicture)+" "+oArtikel:Me
         ENDIF
      ENDIF*/
   ELSE
      ?? " Keine Zeichnung"
   ENDIF
   art->(dbSkip())
ENDDO

Sinkey(0)