PROC RUN_CHANGE_FOLGE
   LOCAL cMatch := Space(25)
   LOCAL getlist := {}
   LOCAL oArt,oBom,nPos,lDo,nRow
   LOCAL aAb,hAB,aBes,hBes
   LOCAL aArtikel := {},nArtnr,lNoStock,nOther,lOther 
   LOCAL nArt,lAuto

   Head("Artikel von Folgeartikel in Stli umwandeln")

   IF ! SystemUser():CheckPermission("U","ART_FOLTOBOM")
      RETURN
   ENDIF

   NetUse("artikel","art")
   NetUse("folgeart","fol")
   NetUse("parts","part")
   NetUSe("engauf","auf")
   NetUse("engbes","bes")
   NetUse("bom","bom")

   lAuto := .F. //Tr_MsgBox("Automatische Umwandlung?",,{"Nein","Ja"}) == 2   

   IF lAuto
      ? "Artikel werden eingelesen..."
      art->(dbSetFilter( {|| art->manufactur == 11 .AND. ! art->LagerArt .AND. AT("KS",art->Matchcode)!=1}, "manufactur == 11 .AND. ! LagerArt .AND. AT('KS',Matchcode)!=1" ))
      art->(dbGoTop())
      DO WHILE ! art->(Eof())
         Aadd(aArtikel,art->Artikelnr)
         art->(dbSkip())
      ENDDO
      art->(dbClearFilter())      
      ?? " fertig. ("+LTrim(str(Len(aArtikel)))+")"
      nArt := 1
   ENDIF
   
   DO WHILE .T.
   //FOR EACH nArtnr IN aArtikel      
      IF ! lAuto
         @ 01,00 SAY "Artikel" GET cMatch VALID {|| ValidVar( cMatch, 01, 08 ) }
         ATail( getlist ):Reader := {| oGet, oGetlist, oMenu, oGetMsg| SwapReader( oGet, oGetList, oMenu, oGetMsg ) }
         READ

         IF LastKey() == 27
            RETURN
         ENDIF

         @ 02,00 CLEAR

         IF art->Lagerart
            @ 03,00 SAY "Artikel ist bereits Lagerf„hig"
            LOOP
         ENDIF
      ELSE
         @ 01,00 CLEAR
         IF nArt > Len(aArtikel) .OR. LastKey() == 27 .OR. Inkey() == 27
            EXIT
         ENDIF
         nArtnr := aArtikel[nArt++]
      ENDIF

      oArt := Artikel():New()  
      oArt:Load(nArtnr)   

      IF lAuto
         @ 01,00 SAY "Artikel "+oArt:Matchcode
      ENDIF

      
      art->(dbSetOrder( 2 ))

      part->(dbSetOrder( 1 ))
      
      IF part->(dbSeek( Str(oArt:Artikelnr,6) ))         
         @ 03,00 SAY "Stckliste bereits vorhanden"
         LOOP
      ENDIF

      fol->(dbSeek( Str(oArt:Artikelnr,6) ))

      lNoStock := .F.
      lOther := .T.

      ? "Folgende Unterartikel sind noch auf Lager, prfe wie wir diese aufbrauchen k”nnen:"
      ? Pad("Artnr.",6),Pad("Matchcode",25),PadL("Bestand",12),Space(4),"Anzahl anderer Artikel mit Verwendung"
      DO WHILE fol->Artikelnr == oArt:Artikelnr .AND. ! fol->(EOF())
         art->(dbSeek( Str(fol->Folgeart,6) ))
         nOther := _GetFolUseCount(fol->FolgeArt)
         ? Str(fol->Folgeart,6),art->Matchcode,PadL(Transform(art->Bestand,Me(art->Me)),12),art->Me,nOther
         IF art->Bestand == 0
            lNoStock := .T.
         ENDIF 
         IF nOther == 0 .AND. art->Bestand != 0
            lOther := .F.
         ENDIF
         fol->(dbSkip())
      ENDDO

      aAb := {}

      auf->(dbSetOrder( 13 ))
      auf->(dbSetFilter({|| auf->Bestat < 3 .AND. auf->VkQty-auf->GelQty > 0},"Bestat < 3 .AND. VkQty-GelQty > 0"))
      IF auf->(dbSeek( Str(oArt:Artikelnr,6) ))
         ?
         ? "Folgende Auftr„ge werden ge„ndert:"
         ? Pad("AB-Nr.",6),"Pos","Menge"
         DO WHILE auf->Artikelnr == oArt:Artikelnr
            ? Str(auf->Abnr,6),Str(auf->Itmnr,3),Transform(auf->VkQty,oArt:cPicture)
            Aadd(aAb,{"NR"=>auf->Abnr,"POS"=>auf->Itmnr})
            auf->(dbSkip())
         ENDDO
      ENDIF
      auf->(dbClearFilter())

      aBes := {}
      bes->(dbSetOrder( 3 ))
      bes->(dbSetFilter( {|| bes->Bestat < 3 .AND. bes->BeQty-bes->GelQty > 0 }, "Bestat < 3 .AND. BeQty-GelQty > 0" ))
      IF bes->(dbSeek( oArt:Matchcode ))
         ?
         ? "Folgende Bestellungen werden ge„ndert:"
         ? Pad("Bes.Nr.",6),"Pos","Menge"
         DO WHILE bes->Matchcode == oArt:Matchcode .AND. ! bes->(EOF())
            ? Str(bes->Besnr,6),Str(bes->Posnr),Transform(bes->BeQty,oArt:cPicture)
            Aadd(aBes,{"NR"=>bes->Besnr,"POS"=>bes->Posnr})
            bes->(dbSkip())
         ENDDO
      ENDIF
      bes->(dbClearFilter())

      IF lAuto
         IF Len(aAB) == 0 .AND. Len(aBes) == 0 .AND. lNoStock .AND. lOther
            ? " Automatische Umwandlung m”glich"
         ELSE
            LOOP
            /*IF Len(aAB) != 0 .AND. Len(aBes) != 0 
               ? "Auftrag oder Bestellung vorhanden"
            ENDIF
            IF ! lOther 
               ? "Letzter Artikel Best„nde hierfr verwenden"         
            ENDIF         */
         ENDIF
      ENDIF         

      IF Sinkey(1) == 27
         RETURN
      ENDIF
      lDo := .F.
      nRow := Row()+1
      @ nRow,00 SAY "Umwandlung durchfhren?" GET lDo PICTURE "Y"
      READ      
      IF ! lDo
         LOOP
      ENDIF
      SetPos(nRow+1,00)
      IF bom->(dbSeek( Str(oArt:Artikelnr,6) ))
         oBom := bom->(Bom_Model():New( .F. ))         
         oBom:Load( oArt:Artikelnr )
      ELSE
         oBom := bom->(Bom_Model():New( .T. ))
         oBom:Artikelnr := oArt:Artikelnr
      ENDIF
      oBom:Date := Date()      
      oBom:Index++ // := 1
      oBom:Used := .F.
      oBom:Save()     
      
      //add old header
      part->(Add_Rec(0))
      part->listart := oArt:Artikelnr
      part->notes := DTOC(DATE())
      part->(dbUnlock())

      fol->(dbSeek( Str(oArt:Artikelnr,6) ))      

      art->(dbSetOrder( 2 ))
      nPos := 1

      DO WHILE fol->Artikelnr == oArt:Artikelnr .AND. ! fol->(EOF())
         art->(dbSeek( Str(fol->Folgeart,6) ))         

         part->(Add_Rec(0))
         part->Pos := nPos++
         part->Me  := oArt:Me
         part->ListArt := oArt:Artikelnr
         part->PartArt := fol->FolgeArt
         part->Bezug   := art->Bezug
         part->Factor  := 1
         part->Qty     := fol->Faktor
         part->(dbUnLock())

         fol->(Rec_Lock(0))
         fol->(dbDelete())
         fol->(dbUnLock())

         oArt:Lagerart := .T.
         oArt:Save()
         
         fol->(dbSkip()) 
      ENDDO

      auf->(dbSetOrder( 1 ))
      FOR EACH hAB IN aAb
         auf->(dbSeek( Str(hAb:Nr,6)+Str(hAb:Pos)))
         auf->(dbSkip())
         DO WHILE auf->Folge .AND. auf->Abnr == hAb:Nr
            art->(dbSeek( Str(auf->Artikelnr,6) ))

            ? auf->Abnr,auf->Itmnr,art->Matchcode

            art->( rec_lock( 0 ) )
            art->vkqty := art->vkqty - (auf->vkqty-auf->GelQty)
            art->( dbUnlock() )     
         
            IF auf->GelQty != 0
               ?? " erledigt"

               auf->(Rec_Lock(0))
               auf->BeStat := 3
               auf->(dbUnLock())
            ELSE
               ?? " gel”scht"            
               
               auf->(Rec_Lock(0))
               auf->(dbDelete())
               auf->(dbUnLock())               
            ENDIF
            auf->(dbSkip())
         ENDDO
      NEXT

      bes->(dbSetOrder( 1 ))
      art->(dbSetOrder( 1 ))
      FOR EACH hBes IN aBes
         bes->(dbSeek( Str(hBes:Nr,6)+Str(hBes:Pos,3) ))
         bes->(dbSkip())
         DO WHILE bes->Folgeto == hBes:Pos .AND. ! bes->(EOF())
            art->(dbSeek( bes->Matchcode ))
            ? bes->Besnr,bes->Posnr,bes->Matchcode
            IF bes->GelQty != 0
               ?? " KANN NICHT GEL™SCHT WERDEN!"
            ELSE
               ?? " gel”scht"              
               bes->(Rec_Lock(0))
               bes->(dbDelete())
               bes->(dbUnLock())               
            ENDIF
            bes->(dbSkip())
         ENDDO
      NEXT

      ? "Umwandlung abgeschlossen"

   ENDDO
   //NEXT

   STATIC FUNCTION _GetFolUseCount(nArtnr)
      LOCAL nCount := -1 //we start with -1 as we only want to count the other ones
      LOCAL nOrd := fol->(IndexOrd())
      LOCAL nRec := fol->(Recno())
      fol->(dbSetOrder( 2 ))
      fol->(dbSeek( Str(nArtnr,6) ))
      DO WHILE fol->FolgeArt == nArtnr
         nCount++
         fol->(dbSkip())
      ENDDO
      fol->(dbGoto( nRec ))
      fol->(dbSetOrder( nOrd ))
   RETURN nCount