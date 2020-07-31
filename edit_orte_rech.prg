#include 'inkey.ch'

FUNCTION RUN_EDIT_ORTE_RECH
   LOCAL nRech := 0
   LOCAL getlist := {}
   LOCAL oPosBrowse,oBrowse
   LOCAL cMe,nArtnr,cMatch,nQty,cLag
   LOCAL nReposnr,nAbnr
   MEMVAR c_four

   NetUse("lagrech","lagr")
   NetUse("englsre","re")
   NetUse("artikel","art")
   NetUse("lager","lag")

   Head("Lagerorte in Rechnung anpassen")
   @ 01,00 SAY "Rechnung" GET nRech PICTURE "999999" VALID __CheckReNr(nRech)   
   READ

   DO WHILE LastKey() != K_ESC      
      re->(dbSetOrder(12))
      re->(dbSeek( Str(nRech,6), .T. ))
      DO WHILE re->RePosnr == 0 .OR. re->AoQty == 0
         re->(dbSkip())
      ENDDO
      art->(dbSetOrder(2))
      oPosBrowse := re->(TBrowseTr():New(03,00,15,MaxCol()))
      oPosBrowse:lBox := .F.
      oPosBrowse:OneColumn := .T.
      oPosBrowse:WhileBlock := {|| re->rechnr == nRech }
      oPosBrowse:cFor := "reposnr != 0 .AND. aoqty != 0"
      //re->(__dbLocate({|| re->(&(oPosBrowse:cFor)) },oPosBrowse:cFor))
      //oPosBrowse:bForBlock
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
      
      art->(dbSeek( Str(re->Artikelnr,6) ))
      cMe := Me(art->Me)
//      nArtnr := re->Artikelnr
//      cMatch := art->Matchcode

      oBrowse := lagr->(TBrowseTr():New(05,10,15,60))
      oBrowse:OneColumn := .T.
      //oBrowse:AddKey(K_ENTER,{|| cRetWert := lag->LagerOrt, .F. })
      //oBrowse:AddKey(Asc("A"),bTaken)
      //oBrowse:AddKey(Asc("a"),bTaken)

      oBrowse:ColorSpec  := c_seven
      
      oBrowse:Title      := "[ Lagerort von dem entfernt werden soll ]"   
      oBrowse:WhileBlock := {|| lagr->Rechnr == nRech .AND. lagr->Reposnr == nReposnr .AND. lagr->Abnr == nAbnr }

      oBrowse:NewColumn("Lagerort",{|| lagr->LagerOrt })   
      oBrowse:NewColumn("Menge",{|| Transform(lagr->LagerMenge,cMe) })   

      oBrowse:AddKey(K_ESC,{|| .F. })
      oBrowse:AddKey(K_ENTER,{||          
         LOCAL getlist := {}
         LOCAL aEnv := SaveEnv()
         LOCAL nRec := lagr->(Recno())
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
                  lagr->(dbGoto(nRec))
                  LagAdd(nArtnr,nQty,lagr->Batch,lagr->LagerOrt)
                  lagr->(Rec_Lock())
                  lagr->lagermenge -= nQty
                  IF lagr->LagerMenge == 0
                     lagr->(dbDelete())
                  ENDIF
                  lagr->(dbUnLock())

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

                  dbSelectArea("LAGR")
                  lagr->(dbSeeK(STR(nRech,6)+STR(nRePosnr,3)+STR(nAbnr,6)))
                  LOCATE FOR lagr->Lagerort == cLag WHILE lagr->Rechnr == nRech .AND. lagr->RePosnr == nRePosnr .AND. lagr->Abnr == nAbnr
                  If lagr->(Found())                     
                     lagr->(Rec_Lock(0))
                     LAGR->LAGERMENGE += nQty
                  Else                     
                     lagr->(ADD_REC())
                     LAGR->LAGERMENGE := nQty
                     LAGR->RECHNR     := nRech
                     LAGR->REPOSNR    := nReposnr
                     LAGR->LAGERORT   := cLag
                     LAGR->ABNR       := nAbnr
                     LAGR->BATCH      := lag->Batch
                  Endif
                  lagr->(dbUNLOCK())
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