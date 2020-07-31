#include 'inkey.ch'
#include 'set.ch'
#xcommand @ <top>, <left>, <bottom>, <right> GET <var>    ;
      TEXT;
      [VALID <valid>];
      [WHEN <when>];
                                                               ;
 => AADD(GetList, _GET_( <var>, <(var)>, NIL, <{valid}>, <{when}>));
  ;ATAIL(GetList):Control := TextGet():New(<top>,<left>,<bottom>,<right>,ATail(GetList));  
  ;ATAIL(GetList):reader := {|g| MemoReader(g) };
  ;ATAIL(GetList):Control:Display()

PROC RUN_CHECK_FREIGABE   
   LOCAL hArt := { => },nArt,oArt,nQty
   LOCAL aLief,nLief,hFrei
   LOCAL hPart
   LOCAL aList

   LOCAL oBrowse   

   //Head("Freigaben prfen")

   NetUse("ppf","ppf")   
   NetUse("ppfreq","ppfr")
   NetUse("engkund","ku")
   NetUse("artikel","art")
   art->(dbSetOrder(2))

   
   IF Tr_MsgBox("Daten aktualisieren",,{"Ja","Nein"}) != 2
      NetUse("engauf","auf")
      NetUse("werkauf","wer")
   
      TxtBox("Bitte warten...","Artikel werden eingelesen")

      Select("auf")
      auf->(dbSetOrder( 14 ))
      //SET RELATION TO Str(auf->Artikelnr) INTO art 
      SET FILTER TO auf->VkQty-auf->GelQty > 0 .AND. ! Empty(auf->Zeichnung)
      /*auf->(OrdScope(0,Str(0,3)))
      auf->(OrdScope(1,Str(3,3)))
*/
      auf->(dbGoTop())

      DO WHILE ! auf->(EOF()) .AND. auf->Bestat < 3 //.AND. nCount < 200         
         _AddEntry(hArt,auf->Artikelnr)         
         hArt[auf->Artikelnr]:Auftrag := .T.
         hArt[auf->Artikelnr]:Qty += auf->VkQty-auf->GelQty        

         IF hArt[auf->Artikelnr]:Usr == 0
            hArt[auf->Artikelnr]:Usr := auf->Buyer
         ELSEIF hArt[auf->Artikelnr]:Usr != auf->Buyer
            hArt[auf->Artikelnr]:Usr := -1
         ENDIF
         
      
         auf->(dbSkip())
      ENDDO
      //SET RELATION TO
      SET FILTER TO
      /*auf->(OrdScope(0))
      auf->(OrdScope(1))*/

      //Sinkey(0)
      
      art->(dbSetOrder( 2 ))
      Select("wer")
      SET RELATION TO Str(wer->Artno) INTO art 
      SET FILTER TO Right(Str(wer->termin,4),2) != "99" .AND. ! Empty(art->Zeichnung ) 

      wer->(dbSetOrder( 9 ))
      wer->(dbGoTop())
      DO WHILE wer->Status == 0
         _AddEntry(hArt,wer->Artno)
         IF  ! hArt[wer->Artno]:Auftrag //es gibt keinen Auftrag fr diesen Artikel, nur dann nehmen wir die Mengen aus den Fertigungsauftr„gen                                   
            hArt[wer->Artno]:Qty += wer->Qty
         ENDIF
         IF ! Empty(wer->Liefma)
            ku->(dbSeek( wer->Liefma+"L" ))
            IF hArt[wer->Artno]:Lief == 0
               hArt[wer->Artno]:Lief := ku->Nummer
            ELSEIF hArt[wer->Artno]:Lief != ku->Nummer
               hArt[wer->Artno]:Lief := -1
            ENDIF
         ENDIF
         wer->(dbSkip())
      ENDDO
      SET RELATION TO 
      SET FILTER TO 

      //add parts from DB to be re-checked if they are not on the list anymore
      ppfr->(dbGoTop())
      DO WHILE ! ppfr->(EOF())
         IF ! ppfr->Artikelnr $ hArt
            hArt[auf->Artikelnr] := {"QTY"=>0,"USR"=>ppfr->User}            
         ENDIF
         ppfr->(dbskip())
      ENDDO
      

      aList := {} //{"Artikelnummer","Matchcode","Fehler"}}

      FOR EACH hPart IN hArt
         nArt := hPart:__eNumKey()
         nQty := hPart:Qty
         oArt := Artikel():New()
         oArt:Load(nArt)
         IF nQty > oArt:Bestand
            //? oArt:Artikelnr,oArt:Matchcode,oArt:IsManufactured
            //LIEFERANTEN mit begonnenem Freigabeprozess suchen            
            ppf->(dbSeek( Str(oArt:Artikelnr,6)+oArt:Zeichnung+oArt:ZeichIndex, .T. ))
            aLief := {}
            DO WHILE ppf->Artikelnr == oArt:Artikelnr .AND. ppf->Zeichnung == oArt:Zeichnung .AND. ppf->ZeichIndex == oArt:ZeichIndex
               IF ! ppf->Lieferant $ aLief
                  Aadd(aLief,ppf->Lieferant)
               ENDIF
               ppf->(dbSkip())
            ENDDO
            
            ku->(dbSetOrder( 8 ))
            IF Len(aLief) == 0 .OR. (hPart:Lief > 0 .AND. ! hPart:Lief $ aLief)
               _AddFreigabeReq(oArt,IF(hPart:Lief > 0 .AND. ! hPart:Lief $ aLief,hPart:Lief,-1),"Freigabeprozess noch nicht begonnen ",hPart:Usr,aList)
            ELSE               
               FOR EACH nLief IN aLief                  
                  oArt:GotoRec()               
                  hFrei := GetFreigabeBesState(nLief)
                  IF ! hFrei:lBes                  
                     _AddFreigabeReq(oArt,nLief,"nicht bestellbar",hPart:Usr,aList)
                  ELSEIF hFrei:nMaxQty > 0 .AND. (nQty == 0 .OR. hFrei:nMaxQty < nQty) //wenn die Menge 0 ist dann ist kein Auftrag mehr vorhanden
                     _AddFreigabeReq(oArt,nLief,"maximale Menge: "+LTrim(Transform(hFrei:nMaxQty,oArt:cPicture))+" ben”tigte Menge: "+LTrim(Transform(nQty,oArt:cPicture)),hPart:Usr,aList)
                  ELSE                     
                     
                     EXIT
                  ENDIF
               NEXT
            ENDIF            
         ENDIF
      NEXT
      ppfr->(dbGoTop())
      DO WHILE ! ppfr->(EOF())
         IF AScan(aList,{|x| x[1] == ppfr->Artikelnr .AND. x[2] == ppfr->Liefnr }) == 0
            ppfr->(Rec_Lock(0))
            ppfr->(dbDelete())
            ppfr->(dbUnLock())
         ENDIF
         ppfr->(dbskip())
      ENDDO
      TxtClear()
   ENDIF

   ppfr->(dbGoTop())

   oBrowse := ppfr->(TbrowseTr():New(01,00,MaxRow(),MaxCol()))

   //oBrowse:lBox := .F.
   oBrowse:ColorSpec := c_six+",W/G,N/G*,R+/W*"
   //oBrowse:OneColumn := .T.
   oBrowse:MultipleRows := .T.
   oBrowse:Title := "[ Fehlende Freigaben ]"

   oBrowse:aIndexedHeaders := {;
         {"TEXT"=>"Artnr","ROW"=>0,"COL"=>0,"ORD"=>1},;
         {"TEXT"=>"Matchcode","ROW"=>0,"COL"=>7,"ORD"=>2};
   }

   oBrowse:NewColumn( Pad("Artnr",6)+" "+Pad("Matchcode",25)+" "+Pad("Lieferant",8)+" Fehler",{|| 
      LOCAL cLief
      ku->(dbSetOrder( 8 ))
      IF ppfr->Liefnr > 0
         ku->(dbSeek( Str(ppfr->Liefnr,6) ))
         cLief := ku->Kunde
      ELSEIF ppfr->Liefnr == 0
         cLief := Pad("intern",8)
      ELSE
         cLief := Space(8)
      ENDIF

      art->(dbSetOrder( 2 ))
      art->(dbSeek( Str(ppfr->Artikelnr,6) ))

      RETURN Pad(Str(ppfr->Artikelnr,6)+" "+art->Matchcode+" "+cLief+" "+ppfr->Status,MaxCol()+1)
   },{|| IF(ppfr->Neu,{7,8},{2,5}) })
   
   oBrowse:NewColumn(Space(7)+"Notiz",{|| 
      LOCAL nX
      LOCAL cText := ""
      FOR nX := 1 TO MlCount(ppfr->Notiz)
         cText += Trim(MemoLine(ppfr->Notiz,,nX))+" "
      NEXT
      //Left(ppfr->Notiz,MaxCol()-1-14) 
      RETURN Space(7)+Left(cText,MaxCol()+1-7) 
   },{|| {1,1} })

   oBrowse:AddKey(27,{|| .F. })
   oBrowse:AddKey(K_F8,{|| art->(dbSetOrder(2)), art->(dbSeek( Str(ppfr->Artikelnr,6))), BrowseArtikel() })
   oBrowse:AddKey(K_ENTER,{|| _EditFreigabeReq() })

   oBrowse:bRestFun  := {|x,y| 
      LOCAL cSeek,nArtnr
      HB_SYMBOL_UNUSED(x)
      IF Len(y) > 0
         __KeyBoard(Chr(y[1]))
      ENDIF
      IF ppfr->(IndexOrd()) == 1
         nArtnr := GetBox(0,"Artikelnummer","999999")
         cSeek := Str(nArtnr,6)
      ELSE
         cSeek := GetBox(Space(25),"Matchcode",,,,,,{|oGet,oGetlist, oMenu, oGetMsg| SwapReader(oGet,oGetList,oMenu,oGetMsg) })
      ENDIF
      IF LastKey() != 27
         ppfr->(dbSeek( cSeek,.T. ))
      ENDIF      
      RETURN .T.
   }
      
   oBrowse:EventLoop()

   //SaveAsCSVInterface(aList)

   STATIC FUNCTION _EditFreigabeReq()
      LOCAL aEnv := SaveEnv()
      LOCAL oArt := Artikel():New()
      LOCAL oRec := ppfr->(Record():New())
      LOCAL lDummy,getlist := {}
      LOCAL lSave := .F.
      LOCAL lEdit :=  SystemUser():HasPermission("U","ART_FREIGABE")
      MEMVAR c_four
      SetColor(c_four)
      IF lEdit
         lEdit := LockEntity("PPFR",oRec:Artikelnr)             
      ENDIF
      oArt:Load(ppfr->Artikelnr)
      oArt:GotoRec() //in case you press F8 in this mask
      IF ppfr->Liefnr > 0
         ku->(dbSetOrder( 8 ))
         ku->(dbSeek( Str(ppfr->Liefnr,6) ))
      ENDIF
      @ 10,10 CLEAR TO 22,75
      @ 10,10 TO 22,75
      @ 11,11 SAY "Artikelnr. "+LTrim(Str(ppfr->Artikelnr))
      @ 12,11 SAY "Matchcode  "+oArt:Matchcode
      @ 13,11 SAY "Lieferant  "+IF(ppfr->Liefnr>0,IF(ppfr->Liefnr==0,"intern",ku->Kunde),"unbekannt")
      @ 14,11 SAY "Fehler     "+ppfr->Status
      @ 15,11 SAY "Verk„ufer  "+IF(ppfr->User<0,"verschiedene",Buy(ppfr->User,.T.))
      @ 16,11 SAY "Notizen    "
      @ 16,22,20,74 GET oRec:Notiz TEXT WHEN lEdit
      IF lEdit
         @ 21,22 GET lDummy PUSHBUTTON CAPTION "Speichern" STATE {|| lSave := .T.,ReadKill(.T.) }
         @ 21,35 GET lDummy PUSHBUTTON CAPTION "Abbrechen" STATE {|| ReadKill(.T.) }
      ELSE
         @ 21,22 GET lDummy PUSHBUTTON CAPTION "Ok" STATE {|| ReadKill(.T.) }
      ENDIF
      READ
      IF lEdit .AND. LastKey() == 27 .AND. oRec:Updated() //ReadUpdated()
         lSave := Tr_MsgBox("Speichern?",,{"Ja","Nein"}) == 1
      ENDIF
      IF lEdit .AND. lSave 
         oRec:Neu := .F.
         oRec:Save()
         UnLockEntity("PPFR",oRec:Artikelnr)
      ENDIF
      RestEnv(aEnv)
   RETURN .T.

   STATIC FUNCTION _AddFreigabeReq(oArt,nLief,cError,nUser,aList)
      Set(_SET_DELETED,.F.)
      IF ! ppfr->(dbSeek( Str(oArt:Artikelnr)+Str(nLief,6) ))
         ppfr->(Add_Rec(0))
         ppfr->Artikelnr := oArt:Artikelnr
         ppfr->Liefnr    := nLief
         ppfr->Neu       := .T.
      ELSE
         ppfr->(Rec_Lock(0))
         IF ppfr->(Deleted())
            ppfr->(dbRecall())
            ppfr->Notiz := ""
         ENDIF
      ENDIF
      ppfr->Matchcode := oArt:Matchcode
      ppfr->User   := nUser
      ppfr->Status := cError
      ppfr->(dbUnLock())
      Aadd(aList,{oArt:Artikelnr,nLief})
      Set(_SET_DELETED,.T.)
   RETURN NIL

   STATIC FUNCTION _AddEntry(hArt,nArtnr)
      IF ! nArtnr $ hArt
         hArt[nArtnr] := {"QTY"=>0,"USR"=>0,"AUFTRAG"=>.F.,"LIEF"=>0}
      ENDIF
   RETURN hArt