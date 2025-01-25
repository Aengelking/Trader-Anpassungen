PROC RUN_ChangeDrawingRevision()
   LOCAL getlist := {}
   LOCAL cMatchcode := Space(25)
   LOCAL cIndex := Space(25),hFreigabe
   LOCAL cFilter
   LOCAL aSuppliers,cLiefma ,aMsg

   LOCAL lStock,lOpenOrder,lOpenPO

   NetUse("artikel","art")
   NetUse("engauf","auf")
   NetUse("engbes","bes")
   NetUse("engkund","ku")
   NetUse("artlief","ali")
   netUse("ppf","ppf")
   
   DO WHILE .T.
      Head("Zeichnungsrevision aktualisieren")
      @ 01,00 SAY "Artikel" GET cMatchcode PICTURE "@K" Valid {|| ValidVar( @cMatchcode, 01, 08, , , , .T. ) }
      ATail( getlist ):Reader := {| oGet, oGetlist, oMenu, oGetMsg| SwapReader( oGet, oGetList, oMenu, oGetMsg ) }
      @ 02,00 SAY "Neue Revision" GET cIndex VALID ! Empty(cIndex)
      
      READ

      IF LastKey() == 27
         RETURN
      ENDIF

      IF art->(dbSeek(cMatchcode))
         IF Trim(cIndex) == Trim(art->Zeichindex)
            Tr_MsgBox("Neue Revision ist identisch mit der aktuellen!")
            LOOP
         ENDIF
         aSuppliers := {}

         cFilter := "bestat <= 2 .OR. (bestat >= 6 .AND. bestat <= 8)"
         bes->(dbSetFilter( {|| bes->(&(cFilter)) }, cFilter ))
         IF bes->(dbSeek( cMatchcode ))
            DO WHILE bes->Matchcode == cMatchcode                                             
               IF ! bes->Liefma $ aSuppliers
                  Aadd(aSuppliers,bes->Liefma)
               ENDIF               
            ENDDO            
         ENDIF
         bes->(dbClearFilter())

         ali->(dbSetOrder( 4 ))
         ali->(dbSeek( Str(art->Artikelnr,6) ))
         DO WHILE ali->Artikelnr == art->Artikelnr
            IF ! ali->Kunde $ aSuppliers
               Aadd(aSuppliers,ali->Kunde)
            ENDIF
            ali->(dbSkip())
         ENDDO

         IF Len(aSuppliers) == 0
            Tr_MsgBox("Keine Lieferanten gefunden!")
            LOOP
         ENDIF
         
         ku->(dbSetOrder( 1 ))
         aMsg := {}
         FOR EACH cLiefma IN aSuppliers 
            Alert(cLiefma)    

            ku->(dbSeek( cLiefma+"L" ))
            hFreigabe := GetArtikelFreigabeStatus(ku->Nummer,.F.,art->Zeichnung,cIndex)
            IF hFreigabe:nNummer == 0
               Aadd(aMsg,Trim(cLiefma)+" keine Freigabe begonnen!")
            ELSE
               Alert(ValToPrg(hFreigabe))
            ENDIF            
         NEXT
         IF Len(aMsg) != 0
            Tr_MsgBox(aMsg)
            LOOP
         ENDIF

         lStock := art->Bestand > 0
         lOpenOrder := ArtikelHasOpenAuftrag(art->Artikelnr)         
      
         IF (lStock .OR. lOpenOrder) .AND. Tr_MsgBox("Handelt es sich nur im eine Zeichnungskorrektur?",,{"Nein","Ja"}) != 2
            LOOP
         ENDIF

         IF lOpenOrder //in this case we will update the orders
            
            auf->( dbSetOrder( 13 ) )
            auf->( dbSeek( Str( art->Artikelnr, 6 ) ) )
            DO WHILE auf->Artikelnr == art->Artikelnr .AND. auf->beStat < 7
               IF auf->Bestat != 3

               ENDIF
               auf->(dbSkip())
            ENDDO
         
         ENDIF
      ELSE
         Tr_MsgBox("Artikel nicht gefunden!")
      ENDIF
   ENDDO

   Sinkey(0)
RETURN