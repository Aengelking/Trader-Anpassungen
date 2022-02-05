/**
     Hiermit k”nnen Restemenge aus verschiedenen Chargen zu einer neuen "Mischcharge" zusammengefhrt werden. 
   **/

PROC RUN_BATCH_MIX
   LOCAL getlist := {}
   LOCAL cMatch := Space(25)
   LOCAL cLag,cNewLag,cBatch,cNewBatch
   LOCAL nMenge
   
   

   NetUse("artikel","art")
   NetUse("lager","lag")
   NetUse("engabg","abg")

   DO WHILE .T.     
      nMenge := 0     

      Head("Mischcharge erzeugen")

      @ 01,00 SAY "Artikel-Matchcode"
      @ 01,18 GET cMatch VALID ValidVar(@cMatch,01,18)
      ATail( getlist ):Reader := {| oGet, oGetlist, oMenu, oGetMsg| SwapReader( oGet, oGetList, oMenu, oGetMsg ) }
      READ

      IF LastKey() == 27
         EXIT
      ENDIF

      IF ! art->(dbSeek( cMatch ))
         Alert("Artikel nicht gefunden")
         LOOP
      ENDIF

      lag->(dbSetOrder( 1 ))
      IF ! lag->(dbSeek( art->Artikelnr ))
         Alert("Keine Lagerbest„nde gefunden")
      ENDIF

      cLag := SHOWORT(03,00,15,50,art->Artikelnr,art->Matchcode,"[ Lagerort/Charge aus der entnommen wird ]")            
      IF LastKey() == 27
         LOOP
      ENDIF
      lag->(dbSetOrder( 2 ))
      lag->(dbSeek( cLag+Str(art->Artikelnr,6) ))
      cBatch := lag->Batch
      nMaxQty := lag->Lagermenge

      cNewLag := SHOWORT(03,00,15,50,art->Artikelnr,art->Matchcode,"[ Lagerort/Charge zu der hinzugefgt wird ]")      
      IF LastKey() == 27
         LOOP
      ENDIF
      lag->(dbSetOrder( 2 ))
      lag->(dbSeek( cNewLag+Str(art->Artikelnr,6) ))
      IF cNewLag == cLag .OR. Trim(cBatch) == Trim(lag->Batch)
         Tr_MsgBox("Lagerort/Charge identisch")
         LOOP
      ENDIF
      cNewBatch := Trim(lag->Batch)+"/"+Trim(cBatch)

      IF Len(cNewBatch) > 35
         Tr_MsgBox("Mischcharge ist bereits ersch”pft. Es k”nnen keine neuen hinzugefgt werden")
         LOOP
      ENDIF

      @ 02,00 SAY "Aus Lagerort"
      @ 02,18 GET cLag WHEN .F.
      @ 02,32 SAY "Charge: "+cBatch
      @ 03,00 SAY "Menge"
      @ 03,18 GET nMenge PICTURE Me(art->Me) VALID nMenge > 0 .AND. nMenge <= nMaxQty
      @ 04,00 SAY "In Lagerort"
      @ 04,18 GET cNewLag WHEN .F.
      @ 04,32 SAY "Neue Charge: "+cNewBatch
      READ
      
      IF LagLook(art->Artikelnr, nMenge, cLag ) != 0 
         Tr_MsgBox("Bestand am Lagerort reicht nicht mehr aus")
         LOOP
      ENDIF
      IF Tr_MsgBox({"Es werden alle Artikel im Lager "+Trim(cNewLag)+" auf die Charge "+Trim(cNewBatch)+" ge„ndert!","Dies kann nicht rckg„ndig gemacht werden!"},,{"abbrechen","durchfhren"}) != 2
         LOOP
      ENDIF

      //Move the stock
      TAKEOFF(art->Artikelnr,nMenge,cLag)
      LAGADD(art->Artikelnr,nMenge,cNewBatch,cNewLag)
      
      //Change the batch no to the new one
      lag->(dbSetOrder( 2 ))
      lag->(dbSeek( cNewLag+Str(art->Artikelnr,6) ))
      lag->(Rec_Lock(0))
      lag->Batch := cNewBatch
      lag->(dbUnLock())

      Bewegung({'UMB',0,Date(),ART->ARTIKELNR,,0,0,nMenge,art->Bestand,'',0,0,,Tr_Getini(28),Trim(cLag)+">"+Trim(cNewLag)})

      //Print the Batch sticker
      MbaseRun(Path("run\print_batch_labels"),{cNewBatch})
   
      
   ENDDO


