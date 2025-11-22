PROC RUN_ChangeDrawingRevision()
   LOCAL getlist := {}
   LOCAL cMatchcode := Space(25)
   LOCAL cIndex := Space(8),hFreigabe,cDrawing := Space(30)
   LOCAL cFilter
   LOCAL aSuppliers,hOpenPO,hOpenMO,cLiefma ,aMsg,nSupplier,nPOArtnr
   LOCAL lCanChangeSO,cNext,aFields
   LOCAL lUntKunde,aOrder

   LOCAL lStock,lOpenOrder,lTech,nNr
   LOCAL lWaldom := .F.
   LOCAL cText


   NetUse("artikel","art")
   NetUse("engauf","auf")
   NetUse("engbes","bes")
   NetUse("engkund","ku")
   NetUse("werkauf","wer")
   NetUse("parts","part")
   NetUse("artlief","ali")
   netUse("ppf","ppf")
   
   DO WHILE .T.
      Head("Zeichnungsrevision aktualisieren")
      @ 01,00 SAY "Artikel      " GET cMatchcode PICTURE "@K" Valid {|| 
         IF ValidVar( @cMatchcode, 01, 14, , , , .T. )
            cDrawing := art->Zeichnung
            RETURN .T.
         ENDIF
         RETURN .F.
      }
      ATail( getlist ):Reader := {| oGet, oGetlist, oMenu, oGetMsg| SwapReader( oGet, oGetList, oMenu, oGetMsg ) }
      @ 02,00 SAY "Zeichnungsnr " GET cDrawing VALID ! Empty(cDrawing)
      @ 03,00 SAY "Neue Revision" GET cIndex //VALID ! Empty(cIndex)
      
      READ

      IF LastKey() == 27
         RETURN
      ENDIF

      art->(dbSetORder( 1 ))
      IF art->(dbSeek(cMatchcode))
         IF Trim(cIndex) == Trim(art->Zeichindex) .AND. cDrawing == art->Zeichnung
            Tr_MsgBox("Neue Revision ist identisch mit der aktuellen!")
            LOOP
         ENDIF
         aSuppliers := {}
         hOpenPO := {=>}
         hOpenMO := {=>}
         
         cFilter := "bestat <= 2 .OR. (bestat >= 6 .AND. bestat <= 8)"
         bes->(dbSetFilter( {|| bes->(&(cFilter)) }, cFilter ))
         IF bes->(dbSeek( cMatchcode ))
            IF art->Bezug >= 5 
               Tr_MsgBox("Fertigungsartikel wurde bestellt - jetzt bin ich ratlos!")
               LOOP
            ENDIF            
            DO WHILE bes->Matchcode == cMatchcode                                             
               IF ! bes->Liefma $ aSuppliers
                  Aadd(aSuppliers,bes->Liefma)                  
               ENDIF          
               IF ! bes->Liefma $ hOpenPO
                  hOpenPO[bes->Liefma] := .F.
               ENDIF     
               bes->(dbSkip())
            ENDDO            
         ENDIF
         bes->(dbClearFilter())
         
         wer->(dbSetOrder( 2 ))
         cFilter := "status < 4"
         wer->(dbSetFilter( {|| wer->(&(cFilter)) }, cFilter ))
         wer->(dbSeek( Str(art->Artikelnr,6) ))
         DO WHILE wer->Artno == art->Artikelnr            
            IF Empty(wer->Liefma) 
               IF ! "" $ aSuppliers
                  Aadd(aSuppliers,"")
               ENDIF
            ELSE
               IF ! wer->Liefma $ aSuppliers
                  Aadd(aSuppliers,wer->Liefma)
               ENDIF
            ENDIF
            IF ! wer->Liefma $ hOpenMO
               hOpenMO[wer->Liefma] := .F.
            ENDIF
            wer->(dbSkip())
         ENDDO
         wer->(dbClearFilter())

         nPOArtnr := art->Artikelnr
         part->(dbSetOrder( 1 ))
         IF art->Bezug >= 5 //Artikel ist eine Baugruppe            
            IF part->(dbSeek( Str(art->Artikelnr,6)+Str(-1,4) )) 
               nPOArtnr := part->Partart
            ELSE
               Aadd(aSuppliers,Space(8)) //internal production
            ENDIF
         ENDIF
         
         ali->(dbSetOrder( 4 ))
         ali->(dbSeek( Str(nPOArtnr,6) ))
         DO WHILE ali->Artikelnr == nPOArtnr
            IF ali->Priority < 9 .AND. ! ali->Kunde $ aSuppliers
               Aadd(aSuppliers,ali->Kunde)
            ENDIF
            ali->(dbSkip())
         ENDDO

         IF Len(aSuppliers) == 0
            Tr_MsgBox("Keine Bezugsquelle (z.B. Lieferant) gefunden!")
            LOOP
         ENDIF


         lStock := art->Bestand > 0
         lOpenOrder := ArtikelHasOpenAuftrag(art->Artikelnr)       
         
         lTech := Tr_MsgBox({"Handelt es sich nur im eine Zeichnungskorrektur,","es hat sich also technisch nichts ge„ndert?"},,{"Nein","Ja"}) != 2
      
         IF (lStock .OR. lOpenOrder) .AND. lTech
            aMsg := {}
            IF lStock
               Aadd(aMsg,"Artikel ist auf Lager")               
            ENDIF
            IF lOpenOrder
               Aadd(aMsg,"Artikel hat offene Auftr„ge")
            ENDIF
            Aadd(aMsg,"Neue Revision als neuer Artikel anlegen!")
            Tr_MsgBox(aMsg)
            LOOP
         ENDIF

         lCanChangeSO := .F.
         
         ku->(dbSetOrder( 1 ))
         aMsg := {}        
         lUntKunde := .F. 
         FOR EACH cLiefma IN aSuppliers
            IF ! Empty(cLiefma)
               ku->(dbSeek( cLiefma+"L" ))
               nSupplier := ku->Nummer
               //art->(dbSetOrder( 2 ))
               //art->(dbSeek( Str(nPOArtnr,6) ))
            ELSE
               nSupplier := 0
               //art->(dbSetOrder(1))
               //art->(dbSeek( cMatchcode ))
            ENDIF
            
            hFreigabe := GetArtikelFreigabeStatus(nSupplier,.F.,cDrawing,cIndex)
            IF hFreigabe:nNummer == 0 .AND. Tr_MsgBox("Freigabelauf "+IF(nSupplier==0,"intern","fr "+Trim(cLiefma))+" starten?",,{"Nein","Ja"}) == 2
               ppf->(dbSetOrder( 3 )) //Str(nummer,10)
               ppf->(dbGoBottom())

               nNr := ppf->Nummer+1 //get new number

               ppf->(Add_Rec(0))
               ppf->Nummer	:= nNr
               ppf->Lieferant  := nSupplier
               ppf->Artikelnr  := art->Artikelnr
               ppf->Zeichnung  := cDrawing
               ppf->ZeichIndex := cIndex
               ppf->(dbUnLock())
               hFreigabe := GetArtikelFreigabeStatus(nSupplier,.F.,cDrawing,cIndex)
            ENDIF
            IF hFreigabe:nNummer == 0
               aOrder := GetFreigabeOrder(art->Artikelnr,nSupplier)
               IF nSupplier == 0
                  cText := "fr interne Freigabe"                  
               ELSE
                  cText := "bei "+Trim(cLiefma)
               ENDIF  
               IF AScan(aOrder,"UNTK") > 0
                  cText := "Unterlagenfreigebe des Kunden "+cText+" eintragen"
               ELSE
                  cText := "Freigabelauf "+cText+" starten"
               ENDIF
               Aadd(aMsg,cText)               
            ELSE
               IF hFreigabe:aState[1] == "DONE" .OR. (lTech .AND. hFreigabe:aState[1] == "UNT")
                  IF Len(hOpenPO) == 0 .AND. Len(hOpenMO) == 0 //no open orders, then we can change the SO
                     lCanChangeSO := .T.
                  ELSE
                     IF cLiefma $ hOpenPO 
                        hOpenPO[cLiefma] := .T.
                     ENDIF
                     IF cLiefma $ hOpenMO
                        hOpenMO[cLiefma] := .T.
                     ENDIF                        
                  ENDIF
               ELSE  //not approved
                  IF cLiefma $ hOpenPO .OR. cLiefma $ hOpenMO
                     cNext := hFreigabe:aState[1]
                     DO WHILE cNext == hFreigabe:aState[1] .OR. ("ignore" $ aFields .AND. ! "forcesonderonignore" $ aFields)
                        cNext := GetNextFreigabeLevel(art->Artikelnr,nSupplier,cNext,.F.)
                        aFields := GetFreigabeFields(cNext)
                     ENDDO
                     Aadd(aMsg,Trim(cLiefma)+" "+IF(!lTech,"vollst„ndge","Liefernantunterlagen-")+"Freigabe notwendig, n„chste Stufe: "+GetFreigabeStatusText({cNext,NIL})+" freigegeben")
                  ELSEIF ! lUntKunde
                     IF hFreigabe:aState[1] == "UNTK" 
                        lUntKunde := .T.
                     ELSE
                        aOrder := GetFreigabeOrder(art->Artikelnr,nSupplier)                        
                        IF AScan(aOrder,"UNTK") < AScan(aOrder,hFreigabe:aState[1])
                           lUntKunde := .T.
                        ENDIF
                     ENDIF
                  ENDIF
               ENDIF
               //Alert(ValToPrg(hFreigabe))
            ENDIF            
         NEXT
         IF Len(aMsg) != 0
            Tr_MsgBox(aMsg)
            LOOP
         ENDIF
         IF ! .F. $ HGetValues(hOpenPO) .AND. ! .F. $ HGetValues(hOpenMO) //all suppliers with open orders have been approved
            lCanChangeSO := .T.
         ENDIF

         art->(dbSetOrder(1))
         art->(dbSeek( cMatchcode ))

         

         IF lOpenOrder //in this case we will update the orders
            IF ! lCanChangeSO
               Tr_MsgBox({"Artikel hat offene Auftr„ge - keine Žnderung m”glich!","Freigabe muss fr alle offenen Bestellungen vorhanden sein!"})
               LOOP               
            ENDIF
            IF ! lUntKunde
               Tr_MsgBox({"Artikel hat offene Auftr„ge - der Kunde muss zuerst die Unterlagen freigeben"})
               LOOP
            ENDIF
            Tr_MsgBox("Hura! Du hast es geschafft. Jetzt k”nnte die Zeichnungsrevision ge„ndert werden!. Aber ich bin noch nicht so weit!")
            LOOP
            /*auf->( dbSetOrder( 13 ) )
            auf->( dbSeek( Str( art->Artikelnr, 6 ) ) )
            DO WHILE auf->Artikelnr == art->Artikelnr .AND. auf->beStat < 7
               IF auf->Bestat != 3

               ENDIF
               auf->(dbSkip())
            ENDDO*/
         ENDIF
         Altd()
         Bewegung({'STD',0,Date(),ART->ARTIKELNR,,0,0,0,art->Bestand,'',0,0,,Tr_Getini(28),"ZNG alt:"+Trim(art->Zeichnung)+" "+Trim(art->Zeichindex)})
         art->(Rec_Lock(0))
         art->Zeichindex := cIndex
         art->Zeichnung := cDrawing
         art->(dbUnlock())
         Tr_MsgBox("Zeichnungsrevision wurde ge„ndert!")
         
      ELSE
         Tr_MsgBox("Artikel nicht gefunden!")
      ENDIF
   ENDDO
RETURN