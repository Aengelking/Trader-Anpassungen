#include 'inkey.ch'

FUNCTION RUN_EDIT_ORTE_RECH
   LOCAL nRech := 0
   LOCAL getlist := {}
   LOCAL oPosBrowse,oBrowse
   LOCAL cMe,nArtnr,cMatch,nQty,cLag
   LOCAL nReposnr,nAbnr
   LOCAL nNr := 0
   LOCAL cLagAli,nPos
  
   MEMVAR c_four,c_seven

   NetUse("lagrech","lagr")
   NetUse("lagent","lage")
   NetUse("englsre","re")
   NetUse("artikel","art")
   NetUse("lager","lag")
   NetUse("lagerne","lne")
   NetUse("ups","ups")

   Head("Lagerorte in Rechnung anpassen")
   @ 01,00 SAY "Rechnung" GET nRech PICTURE "999999" VALID (LastKey() == K_ENTER .AND. nRech == 0) .OR. __CheckReNr(nRech,nNr)  
   @ 02,00 SAY "Entnahme" GET nNr  PICTURE "999999" WHEN nRech == 0 VALID __CheckNr(nNr,@nRech)  
   READ

   

   DO WHILE LastKey() != K_ESC   
      art->(dbSetOrder(2))

      IF nRech != 0   
         cLagAli := "lagr"

         re->(dbSetOrder(12))
         re->(dbSeek( Str(nRech,6), .T. ))
         DO WHILE re->RePosnr == 0 .OR. re->AoQty == 0
            re->(dbSkip())
         ENDDO
         
         
         oPosBrowse := re->(TBrowseTr():New(03,00,15,MaxCol()))
         oPosBrowse:lBox := .F.
         oPosBrowse:OneColumn := .T.
         
         oPosBrowse:WhileBlock := {|| re->rechnr == nRech }
         oPosBrowse:cFor := "reposnr != 0 .AND. aoqty != 0"      

         oPosBrowse:NewColumn("Pos",{|| Str(re->rePosnr,3) })
         oPosBrowse:NewColumn("Artikel",{|| art->(dbSeek( Str(re->Artikelnr,6)) ),art->Matchcode })
         oPosBrowse:NewColumn("Menge",{|| Transform(re->AoQty,Me(art->Me)) })
         oPosBrowse:AddKey(K_ESC,{|| .F. })
         oPosBrowse:AddKey(K_ENTER,{|| 
            art->(dbSeek( Str(re->Artikelnr,6)) )
            nArtnr := re->Artikelnr
            cMatch := art->Matchcode
            IF art->Lagerart
               nReposnr := re->Reposnr
               nAbnr    := re->Abnr
               lagr->(dbSeek( Str(nRech,6)+Str(re->Reposnr,3)+Str(re->Abnr,6) ))
               oBrowse:Rebuild := .T.
               oBrowse:Display()
               oBrowse:EventLoop()
            ELSE
               Tr_MsgBox("Nicht Lagerf„hig")
            ENDIF
            RETURN .T.
         })   
      ELSE
         cLagAli := "lage"

         lne->(dbSeek( nNr )) 
         oPosBrowse := lne->(TBrowseTr():New(03,00,15,MaxCol()))
         oPosBrowse:lBox := .F.
         oPosBrowse:OneColumn := .T.
         oPosBrowse:WhileBlock := {|| lne->Nummer == nNr }
         oPosBrowse:NewColumn("Pos",{|| Str(lne->Pos,3) })
         oPosBrowse:NewColumn("Artikel",{|| art->(dbSeek( Str(lne->Artikelnr,6)) ),art->Matchcode })
         oPosBrowse:NewColumn("Menge",{|| Transform(lne->Menge,Me(lne->Me)) })
         oPosBrowse:AddKey(K_ESC,{|| .F. })
         oPosBrowse:AddKey(K_ENTER,{|| 
            art->(dbSeek( Str(lne->Artikelnr,6)) )
            nArtnr := lne->Artikelnr
            cMatch := art->Matchcode
            IF art->Lagerart
               nPos := lne->Pos               
               lage->(dbSeek( Str(nNr,6)+Str(lne->Pos,3) ))
               oBrowse:Rebuild := .T.
               oBrowse:Display()
               oBrowse:EventLoop()
            ELSE
               Tr_MsgBox("Nicht Lagerf„hig")
            ENDIF
            RETURN .T.
         })   
      ENDIF

      IF nRech != 0
         art->(dbSeek( Str(re->Artikelnr,6) ))
      ELSE
         art->(dbSeek( Str(lne->Artikelnr,6)))
      ENDIF
      cMe := Me(art->Me)

      oBrowse := (cLagAli)->(TBrowseTr():New(05,10,15,60))
      oBrowse:OneColumn := .T.
      oBrowse:ColorSpec  := c_seven
      
      oBrowse:Title      := "[ Lagerort von dem entfernt werden soll ]"   
      IF nRech != 0
         oBrowse:WhileBlock := {|| (cLagAli)->Rechnr == nRech .AND. (cLagAli)->Reposnr == nReposnr .AND. (cLagAli)->Abnr == nAbnr }
      ELSE
         oBrowse:WhileBlock := {|| (cLagAli)->Nummer == nNr .AND. (cLagAli)->Pos == nPos }
      ENDIF

      oBrowse:NewColumn("Lagerort",{|| (cLagAli)->LagerOrt })   
      oBrowse:NewColumn("Menge",{|| Transform((cLagAli)->LagerMenge,cMe) })   

      oBrowse:AddKey(K_ESC,{|| .F. })
      oBrowse:AddKey(K_ENTER,{||          
         LOCAL getlist := {}
         LOCAL aEnv := SaveEnv()
         LOCAL nRec := (cLagAli)->(Recno())
         LOCAL cTitle := "[ Lagerort von dem hinzugefgt wird ]"
         SetColor(c_seven)
         @ 17,10 CLEAR TO 27,60
         @ 17,10 TO 27,60 DOUBLE
         @ 17,33-Round(Len(cTitle)/2,0) SAY cTitle  
         cLag := SHOWORT(17,10,27,60,nArtnr,cMatch,cTitle) 
         IF LastKey() != K_ESC .AND. Len(cLag) != 0
            SetColor(c_seven)
            nQty := 0
            //@ 18,10 CLEAR TO 27,60
            @ 19,11 SAY "Lagerort "+cLag
            @ 20,11 SAY "Menge   " GET nQty PICTURE cMe VALID {|| 
               lag->(dbSetOrder( 2 ))
               IF ! lag->(dbSeek( cLag+Str(nArtnr,6) ))
                  @ 20,30 SAY "Keine Menge mehr vorhanden"
                  RETURN .F.
               ELSEIF nQty > lag->LagerMenge
                  @ 20,30 SAY "Maximal: "+LTrim(Transform(lag->LagerMenge,cMe))
               ENDIF
               RETURN nQty <= lag->LagerMenge               
            }            
            READ
            IF LastKey() != K_ESC
               IF lag->(dbSeek( cLag+Str(nArtnr,6) ))                  
                  (cLagAli)->(dbGoto(nRec))
                  LagAdd(nArtnr,nQty,(cLagAli)->Batch,(cLagAli)->LagerOrt)
                  (cLagAli)->(Rec_Lock())
                  (cLagAli)->lagermenge -= nQty
                  IF (cLagAli)->LagerMenge == 0
                     (cLagAli)->(dbDelete())
                  ENDIF
                  (cLagAli)->(dbUnLock())

                  IF lag->LagerMenge <= nQty
                     lag->(Rec_Lock(0))
                     lag->(dbDelete())
                     lag->(dbUnLock())
                  ELSEIF LAG->LAGERMENGE > nQty
                     lag->(Rec_Lock(0))
                     lag->Lagermenge -= nQty
                     lag->Taken := .T.
                     lag->(dbUnLock())                     
                  ENDIF

                  dbSelectArea(cLagAli)
                  IF nRech != 0                  
                     (cLagAli)->(dbSeeK(STR(nRech,6)+STR(nRePosnr,3)+STR(nAbnr,6)))
                     LOCATE FOR (cLagAli)->Lagerort == cLag WHILE (cLagAli)->Rechnr == nRech .AND. (cLagAli)->RePosnr == nRePosnr .AND. (cLagAli)->Abnr == nAbnr
                  ELSE
                     (cLagAli)->(dbSeek( Str(nNr,6)+Str(nPos,3) ))
                     LOCATE FOR (cLagAli)->Lagerort == cLag WHILE (cLagAli)->Nummer == nNr .AND. (cLagAli)->Pos == nPos 
                  ENDIF

                  If (cLagAli)->(Found())                     
                     (cLagAli)->(Rec_Lock(0))
                     (cLagAli)->LAGERMENGE += nQty
                  Else                     
                     (cLagAli)->(ADD_REC())
                     (cLagAli)->LAGERMENGE := nQty
                     IF nRech != 0
                        (cLagAli)->RECHNR     := nRech
                        (cLagAli)->REPOSNR    := nReposnr
                        (cLagAli)->ABNR       := nAbnr
                     ELSE
                        (cLagAli)->NUMMER     := nNr
                        (cLagAli)->POS        := nPos
                     ENDIF
                     (cLagAli)->LAGERORT   := cLag
                     
                     (cLagAli)->BATCH      := lag->Batch
                  Endif
                  (cLagAli)->(dbUNLOCK())
               ENDIF
            ENDIF
         ENDIF
         RestEnv(aEnv,.T.)
         RETURN .T.
      })
      

      oPosBrowse:EventLoop()
   
   ENDDO

RETURN NIL

STATIC FUNCTION __CheckReNr(nRechnr)
   re->(dbSetOrder(4))
  If ! re->(CHECK(STR(nRechnr,6),"''",01,25,1,0))
    RETURN(.F.)
  Endif
RETURN .T.

STATIC FUNCTION __CheckNr(nNr)
   ups->(dbSetOrder(4))
   ups->(dbSeek(nNR))   
   //IF ! ups->(Found())
      IF ! lne->(Check(nNr,"''",02,20,1,0))
         RETURN(.F.)
      ENDIF
   /*ELSE
      @ 02,25 SAY "Bereits gebucht!"
      RETURN .F.
   ENDIF*/
RETURN .T.