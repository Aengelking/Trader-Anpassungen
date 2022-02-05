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
   LOCAL aLief,nLief,hFrei,aLiefFrei
   LOCAL hPart,hPPF
   LOCAL aList
   LOCAL aState
   LOCAL lShowComplete := .F.,oShowComplete,getlist := {}
   LOCAL hPPFData
   LOCAL nX

   LOCAL oBrowse   
   LOCAL oFilter

   MEMVAR c_five,c_six

   LOCAL bSkip := {||
      LOCAL nRow := oBrowse:rowPos
      IF Eval(oBrowse:ForBlock)
         ppfr->(dbSetFilter(oBrowse:ForBlock,oBrowse:cFor))
         ppfr->(dbSkip())
         IF ppfr->(EOF())
            ppfr->(dbSkip(-1))
         ENDIF
         ppfr->(dbClearFilter())
      ENDIF
      IF nRow == 1
         oBrowse:goTop()
      ENDIF
      RETURN NIL
   }
   LOCAL bSetFilter := {||
      oBrowse:SetFilter(oFilter,"! ppfr->complete",{|| ! lShowComplete } )      
      RETURN NIL
   }
   LOCAL bRebuild := {||         
      Eval(bSetFilter)
      oBrowse:Rebuild := .T.   
      Eval(bSkip)
      RETURN NIL
   }
   

   //Head("Freigaben prfen")

   NetUse("ppf","ppf")   
   NetUse("ppfreq","ppfr")
   NetUse("ppfdat","ppfd")
   NetUse("engkund","ku")
   NetUse("artikel","art")
   NetUse("artlief","ali")
   NetUse("engbes","bes")
   NetUse("engabg","abg")

   art->(dbSetOrder(2))

   
   IF Tr_MsgBox("Daten aktualisieren",,{"Ja","Nein"}) != 2
      NetUse("engauf","auf")
      NetUse("werkauf","wer")
      NetUse("muster","mus")
   
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

         IF Empty(hArt[auf->Artikelnr]:Kunde) 
            hArt[auf->Artikelnr]:Kunde := auf->Kundma
         ELSEIF hArt[auf->Artikelnr]:Kunde != auf->Kundma
            hArt[auf->Artikelnr]:Kunde := "@"
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

      Select("mus")
      mus->(dbSetOrder( 6 ))      
      SET RELATION TO Str(mus->Artikelnr) INTO art 
      SET FILTER TO ! Empty(art->Zeichnung)

      mus->(dbGoTop())

      DO WHILE ! mus->(EOF()) .AND. mus->Status < 3 //.AND. nCount < 200         
         _AddEntry(hArt,mus->Artikelnr)         
         hArt[mus->Artikelnr]:Auftrag := .T.
         hArt[mus->Artikelnr]:Qty += mus->Menge

         IF hArt[mus->Artikelnr]:Usr == 0
            hArt[mus->Artikelnr]:Usr := mus->Buyer
         ELSEIF hArt[mus->Artikelnr]:Usr != mus->Buyer
            hArt[mus->Artikelnr]:Usr := -1
         ENDIF

         IF Empty(hArt[mus->Artikelnr]:Kunde) 
            hArt[mus->Artikelnr]:Kunde := mus->Kunde
         ELSEIF hArt[mus->Artikelnr]:Kunde != mus->Kunde
            hArt[mus->Artikelnr]:Kunde := "@"
         ENDIF
         
      
         mus->(dbSkip())
      ENDDO      
      SET RELATION TO
      SET FILTER TO
      
      //Alle Artikel mit Zeichnung
      /*Select("art")
      art->(dbSetFilter({|| ! Empty(art->Zeichnung) .AND. ! art->Obsolete .AND. art->Lagerart },"! Empty(Zeichnung) .AND. ! Obsolete .AND. Lagerart"))
      ali->(dbSetOrder( 4 ))

      art->(dbGoTop())
      DO WHILE ! art->(EOF()) 
         IF ali->(dbSeek( Str(art->Artikelnr) ))
            _AddEntry(hArt,art->Artikelnr)         
            IF hArt[art->Artikelnr]:Qty == 0
               hArt[art->Artikelnr]:Qty := 1
            ENDIF
         ENDIF
         art->(dbSkip())
      ENDDO

      SET FILTER TO*/   

      
      //add parts from DB to be re-checked if they are not on the list anymore
      ppfr->(dbGoTop())
      DO WHILE ! ppfr->(EOF())
         IF !ppfr->Complete .AND. ! ppfr->Artikelnr $ hArt
            hArt[ppfr->Artikelnr] := {"QTY"=>1,"USR"=>ppfr->User,"LIEF"=>ppfr->Liefnr,"KUNDE"=>""}            
         ENDIF
         ppfr->(dbskip())
      ENDDO

      TxtClear()

      TxtBox("     /"+Pad(LTrim(Str(Len(hArt),5)),5),"Freigaben werden gerpft")

      aList := {} //{"Artikelnummer","Matchcode","Fehler"}}

      FOR EACH hPart IN hArt
         @ MaxRow()/2+2,MaxCol()/2-5 SAY Str(hPart:__enumIndex(),5) COLOR c_five
         nArt := hPart:__eNumKey()
         nQty := hPart:Qty
         oArt := Artikel():New()
         oArt:Load(nArt)

         IF nQty > oArt:Bestand
            //? oArt:Artikelnr,oArt:Matchcode,oArt:IsManufactured
            //LIEFERANTEN mit begonnenem Freigabeprozess suchen            
            ppf->(dbSeek( Str(oArt:Artikelnr,6)+oArt:Zeichnung+oArt:ZeichIndex, .T. ))
            aLief := {}
            aLiefFrei := {}
            hPPF  := {=>}
            hPPFData := {=>}
            DO WHILE ppf->Artikelnr == oArt:Artikelnr .AND. ppf->Zeichnung == oArt:Zeichnung .AND. ppf->ZeichIndex == oArt:ZeichIndex
                                 
               aState := GetFreigabeStatus()

               IF oArt:Artikelnr == 13493
                  //Alert(ValToPrg(aState))
               ENDIF

               IF  ! (aState[1] == "DONE" .AND. ! aState[2]) //nicht abgebrochen
                  IF ! ppf->Lieferant $ aLief
                     Aadd(aLief,ppf->Lieferant)                     
                  ENDIF                       
                  hPPF[ppf->Lieferant] := ppf->Nummer
                  hPPFData[ppf->Nummer] := aState                  
               ENDIF
               
               ppf->(dbSkip())
            ENDDO
            ali->(dbSetOrder( 4 ))
            ku->(dbSetOrder( 1 ))
            ali->(dbSeek( Str(oArt:Artikelnr) ))

            DO WHILE ali->Artikelnr == oArt:Artikelnr .AND. ! ali->(EOF())
               ku->(dbSeek( ali->Kunde+"L" ))
               IF ! ku->Nummer $ aLief .AND. ali->Priority != 9
                  Aadd(aLief,ku->Nummer)
                  //hPPF[ku->Nummer] := 0
                  //hPPFData[0] := {,,.F.}
               ELSEIF  (nX := AScan(aLief,ku->Nummer)) != 0 .AND. ali->Priority == 9  //Lieferant wurde deaktiviert
                  HB_ADel(aLief,nX,.T.)
               ENDIF
               ali->(dbSkip())
            ENDDO

            
            ku->(dbSetOrder( 8 ))
            IF Len(aLief) == 0 .OR. (hPart:Lief > 0 .AND. ! hPart:Lief $ aLief)
               _AddFreigabeReq(oArt,IF(hPart:Lief > 0 .AND. ! hPart:Lief $ aLief,hPart:Lief,-1),"Freigabeprozess noch nicht begonnen ",hPart:Usr,aList,0,hPart["KUNDE"])
            ELSE               
               FOR EACH nLief IN aLief                  
                  oArt:GotoRec()               
                  hFrei := GetFreigabeBesState(nLief)
                  IF oArt:Artikelnr == 13493
                  //   Alert(ValToPrg(hFrei))
                  ENDIF
                  IF ! hFrei:lBes                  
                     _AddFreigabeReq(oArt,nLief,"nicht bestellbar",hPart:Usr,aList,IF(nLief$hPPF,hPPF[nLief],0),hPart["KUNDE"])
                  ELSEIF hFrei:nMaxQty > 0 .AND. (nQty == 0 .OR. hFrei:nMaxQty < nQty) //wenn die Menge 0 ist dann ist kein Auftrag mehr vorhanden
                     _AddFreigabeReq(oArt,nLief,"maximale Menge: "+LTrim(Transform(hFrei:nMaxQty,oArt:cPicture))+" ben”tigte Menge: "+LTrim(Transform(nQty,oArt:cPicture)),hPart:Usr,aList,IF(nLief$hPPF,hPPF[nLief],0),hPart["KUNDE"])
                  ELSEIF ! oArt:Obsolete .AND. nLief $ hPPF 
                     IF ! nLief $ hPPf 
                        //_AddFreigabeReq(oArt,nLief,"Freigabeprozess noch nicht begonnen ("+LTrim(Str(nLief))+")",hPart:Usr,aList,0,hPart["KUNDE"])
                     ELSEIF hPPF[nLief] == 0 .OR. hPPFData[hPPF[nLief]][1] != "DONE" .OR. hPPFData[hPPF[nLief]][3] //nicht freigegeben oder Sonderfreigabe
                        _AddFreigabeReq(oArt,nLief,"wartend (PPF: "+LTrim(Str(hPPF[nLief]))+IF(hPPFData[hPPF[nLief]][3],", Sonderfreigabe","")+")",hPart:Usr,aList,hPPF[nLief],hPart["KUNDE"])
                     ENDIF
                  ELSE
                     EXIT
                  ENDIF
               NEXT
            ENDIF
         ENDIF
      NEXT
      ppfr->(dbGoTop())
      DO WHILE ! ppfr->(EOF())
         IF  AScan(aList,{|x| x[1] == ppfr->Artikelnr .AND. x[2] == ppfr->Liefnr }) == 0            
            ppfr->(Rec_Lock(0))
            IF ppfr->Liefnr == -1
               ppfr->(dbDelete())
            ELSE
               IF ! ppfr->Complete
                  //Alert("Complete "+ppfr->Matchcode)
               ENDIF
               ppfr->Complete := .T.
            ENDIF
            ppfr->(dbUnLock())
         ENDIF
         ppfr->(dbskip())
      ENDDO
      TxtClear()
   ENDIF

   ppfr->(dbGoTop())

   oBrowse := ppfr->(TbrowseTr():New(02,01,MaxRow()-1,MaxCol()-1))

   oBrowse:lBox := .F.
   oBrowse:ColorSpec := c_six+",W/G,N/G*,R+/W*"
   //oBrowse:OneColumn := .T.
   oBrowse:MultipleRows := .T.
   oBrowse:Title := "[ Fehlende Freigaben ]"

   SetColor(c_six)
   @ 00,00 CLEAR TO MaxRow(),MaxCol()
   @ 00,00 TO MaxRow(),MaxCol() DOUBLE
   @ 00,02 SAY "[ Fehlende Freigaben ]"

   oBrowse:aIndexedHeaders := {;
         {"TEXT"=>"Artnr","ROW"=>0,"COL"=>0,"ORD"=>1},;
         {"TEXT"=>"Matchcode","ROW"=>0,"COL"=>7,"ORD"=>2};
   }

   //oBrowse:cFor := "! ppfr->complete"
   //oBrowse:ForBlock := {|| &(oBrowse:cFor)}
   Eval(bSetFilter)

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

      RETURN Pad(Str(ppfr->Artikelnr,6)+" "+art->Matchcode+" "+cLief+" "+IF(ppfr->Complete,"ABGESCHLOSSEN",ppfr->Status),MaxCol()+1)
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
   oBrowse:AddKey(K_SPACE,{|| _EditFreigabeReq(.F.) })

   oBrowse:AddKey( K_F11, {||
      LOCAL cCol := SetColor(c_five)      
      IF oFilter == NIL
         oFilter := InteractiveFilter():New(00,02,05)
         oFilter:AddValue("Lieferant",'liefma',Space(8),"@!")         
      ENDIF
      oFilter:Dialog()

      //oBrowse:SetFilter(oFilter)
      Eval(bSetFilter)
      SetColor(cCol)
      RETURN .T.
   },"Filter")

   oBrowse:AddKey(K_LBUTTONDOWN,{||   
      IF oShowComplete:HitTest(MRow(),MCol()) != 0                  
         oShowComplete:Select()
         //Eval(bRebuild)
      ENDIF
      RETURN .T.
   })

   IF Tr_Getini(28) == 9
      oBrowse:AddKey(K_DEL,{||
         IF Tr_MsgBox("L”schen?",,{"Ja","Nein"}) == 1
            ppfr->(Rec_Lock())
            ppfr->(dbDelete())
            ppfr->(dbUnLock())
         ENDIF
         RETURN .T.
      })
   ENDIF
   

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

   oBrowse:goTop()
   oBrowse:nTop := oBrowse:nTop //there is some kind of bug in the TBrowse class which makes it not display it correctly. If we do this it solves the problem   
      
   oBrowse:Display()
   SetColor(c_six)
   @ 01,55 GET lShowComplete CHECKBOX CAPTION "Abgeschlossene anzeigen"
   oShowComplete := ATAIL(GetList):Control
   oShowComplete:sBlock := {|| lShowComplete := oShowComplete:Buffer, Eval(bRebuild) }

   oBrowse:EventLoop()

   //SaveAsCSVInterface(aList)

   STATIC FUNCTION _EditFreigabeReq(lEdit)
      LOCAL aEnv := SaveEnv()
      LOCAL oArt := Artikel():New()
      LOCAL oRec := ppfr->(Record():New())
      LOCAL lDummy,getlist := {}
      LOCAL cNextText,aLevel,cNext,cNextType
      LOCAL lSave := .F.     
      LOCAL nR,nRight,nBottom
      LOCAL nBes,nMat,cFilter,lMusSend := .F.
      LOCAL oLief
      MEMVAR c_four
      SetColor(c_four)
      IF ValType(lEdit) != "L" .OR. lEdit
         lEdit :=  SystemUser():HasPermission("U","ART_FREIGABE")
      ENDIF
      IF lEdit
         lEdit := LockEntity("PPFR",oRec:Artikelnr)             
      ENDIF
      oArt:Load(ppfr->Artikelnr)
      oArt:GotoRec() //in case you press F8 in this mask
      IF ppfr->Liefnr > 0
         oLief := Adresse():New()
         oLief:Load(ppfr->Liefnr)
      ENDIF
      IF ppfr->PPF != 0
         ppf->(dbSetOrder( 3 ))
         ppf->(dbSeek( Str(ppfr->PPf,10) ))
         //ppf->(dbSeek( Str(oArt:Artikelnr,6)+oArt:Zeichnung+oArt:ZeichIndex+Str(ppfr->Liefnr,6), .T. ))
         aLevel := GetFreigabeStatus(.T.)
      ELSE
         aLevel := {"",.F.,.F.,0,Stod("",0)}
      ENDIF
      cNext  := GetNextFreigabeLevel(ppfr->Artikelnr,ppfr->Liefnr,aLevel[1])
      cNextText := GetFreigabeStatusText({cNext,NIL})
      nRight := 82
      nBottom := 32
      @ 02,10 CLEAR TO nBottom,nRight
      @ 02,10 TO nBottom,nRight
      @ 03,11 SAY "Artikelnr. "+LTrim(Str(ppfr->Artikelnr))
      @ 04,11 SAY "Matchcode  "+oArt:Matchcode
      @ 05,11 SAY "Lieferant  "+IF(ppfr->Liefnr>=0,IF(ppfr->Liefnr==0,"intern",oLief:Kunde),"unbekannt")
      nR := 05
      IF ppfr->Liefnr > 0
         bes->(dbSetOrder( 8 ))
         nBes := bes->(LETO_SUM("beqty-gelqty",'bestat<3 .AND. released',oLief:Kunde+oArt:Matchcode,oLief:Kunde+oArt:Matchcode))
         nMat := bes->(LETO_SUM("beqty-gelqty","bestat<3 .AND. ! released",oLief:Kunde+oArt:Matchcode,oLief:Kunde+oArt:Matchcode))
         @ ++nR,11 SAY "Bestellt  "+Transform(nBes,oArt:cPicture)+" "+oArt:Me
         @ ++nR,11 SAY "Mat.freig."+Transform(nMat,oArt:cPicture)+" "+oArt:Me
      ENDIF   
      
      @ ++nR,11 SAY "Verk„ufer  "+IF(ppfr->User<0,"verschiedene",Buy(ppfr->User,.T.))
      @ ++nR,11 SAY "Fehler     "+ppfr->Status      
      @ ++nR,11 SAY Replicate(Chr(196),nRight-11)
      @ nR,12 SAY " Verlauf "
      IF ppfr->PPF != 0
         ppfd->(dbSetOrder( 2 ))
         ppfd->(dbSeek( Str(ppfr->PPF,10) ))
         Do While ppfd->PPF == ppfr->PPF
            //@ nR,00 SAY ppfd->Type
         
            @ ++nR,11 SAY ppfd->Datum
            @ nR,22 SAY GetFreigabeStatusText({Trim(ppfd->Type),ppfd->Free})
            @ nR,52 SAY Pad(Buy(ppfd->User,.T.),30)
            If ! Empty(ppfd->Address)
               nR++
               ku->(dbSeek( Str(ppfd->Address,6) ))
               @ nR,22 SAY Pad(Trim(Trim(ku->Name1)+" "+ku->Name2),60)
               @ ++nR,22 SAY GetContact(ppfd->Contact)["name"]
            Endif
            IF Trim(ppfd->Type) == "DONE" .AND. ppf->Sonderfrei
               @ ++nR,22 SAY t("Sonderfreigabe")
               If ppf->Menge != 0
                  @ ++nR,24 SAY t("für % %",{LTrim(Transform(ppf->Menge,Me(art->Me))),art->Me})
                  @ ++nR,24 SAY t("verbraucht % %",{LTrim(Transform(ppf->Verbraucht,Me(art->Me))),art->Me})
               Endif
               If ppf->Bis > STod("")
                  @ ++nR,24 SAY DToC(ppf->Bis)
               Endif
            ELSEIF (Trim(ppfd->Type) == "UNT" .AND. ppfd->Free) .OR. Trim(ppfd->Type) == "MUS"
               
               cFilter := 'Trim(Buart) $ '
               IF Trim(ppfd->Type) == "UNT" .OR. (Trim(ppfd->Type)=="MUS" .AND. ! ppfd->Free)
                  cFilter += '"WE-WA" .AND. liefma == "'+oLief:Kunde+'"'
               ELSE
                  cFilter += '"ENT-RNR"'
               ENDIF
               cFilter += ' .AND. Datum >= Stod("'+DtoS(ppfd->Datum)+'")'
               ppfd->(dbSkip())
               IF ppfd->PPF == ppfr->PPF
                  cFilter += ' .AND. Datum <= Stod("'+DtoS(ppfd->Datum)+'")'
                  cNextType := ppfd->Type
               ELSE
                  cNextType := ""
               ENDIF
               ppfd->(dbSkip(-1))     
               IF Trim(ppfd->Type) == "MUS" .OR. (Trim(ppfd->Type) == "UNT" .AND. (Trim(cNextType) == "MUS" .OR. Empty(cNextType))) 
                  abg->(dbSetOrder( 3 ))
                  abg->(dbSetFilter({|| abg->(&(cFilter))},cFilter))            
                  //abg->(dbSeek( Descend(oArt:Matchcode) ))            
                  abg->(dbSeek( oArt:Matchcode ))            
                  IF abg->(Found()) //dbSeek( Descend(oArt:Matchcode) ))
                     @ ++nR,11 SAY abg->Datum
                     @ nr,22 SAY "Muster "+IF(Trim(ppfd->Type)=="MUS".AND.ppfd->Free,"versandt","erhalten")
                     IF Trim(ppfd->Type) == "MUS"
                        lMusSend := .T.
                     ENDIF
                  ELSEIF Trim(ppfd->Type) == "MUS" .AND. cNextType == ""                  
                     cNextText := "Muster"
                  ENDIF               
                  abg->(dbClearFilter())
               ENDIF
            ENDIF
            ppfd->(dbSkip())
         Enddo
      ENDIF
      IF ppfr->PPF == 0 .OR. ! ppf->Freigabe .OR. ppf->Sonderfrei
         @ ++nR,11 SAY "N„chstes   "
         @ nR,22 SAY cNextText+IF(cNext != "",IF(Trim(aLevel[1])=="MUS".AND.!lMusSend," versenden"," freigeben"),"")
      ENDIF
      @ ++nR,11 SAY Replicate(Chr(196),nRight-11)
      @ ++nR,11 SAY "Notizen    "
      @ nR,22,nBottom-2,74 GET oRec:Notiz TEXT WHEN lEdit
      IF lEdit
         @ nBottom-1,22 GET lDummy PUSHBUTTON CAPTION "Speichern" STATE {|| lSave := .T.,ReadKill(.T.) }
         @ nBottom-1,35 GET lDummy PUSHBUTTON CAPTION "Abbrechen" STATE {|| ReadKill(.T.) }
      ELSE
         @ nBottom-1,22 GET lDummy PUSHBUTTON CAPTION "Ok" STATE {|| ReadKill(.T.) }
      ENDIF
      READ
      IF lEdit .AND. LastKey() == 27 .AND. oRec:Updated() //ReadUpdated()
         lSave := Tr_MsgBox("Speichern?",,{"Ja","Nein"}) == 1
      ENDIF
      IF lEdit 
         IF lSave 
            oRec:Neu := .F.
            oRec:Save()
         ENDIF
         UnLockEntity("PPFR",oRec:Artikelnr)
      ENDIF
      RestEnv(aEnv)
   RETURN .T.

   STATIC FUNCTION _AddFreigabeReq(oArt,nLief,cError,nUser,aList,nPPF,cKunde)
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
            //ppfr->Notiz := ""
         ENDIF
         ppfr->Complete := .F.
      ENDIF
      IF nLief > 0
         ku->(dbSetOrder(8))
         ku->(dbSeek( Str(nLief,6) ))
         ppfr->Liefma := ku->Kunde
      ENDIF
      ppfr->Matchcode := oArt:Matchcode
      ppfr->User   := nUser
      ppfr->Status := cError
      ppfr->PPF    := nPPF
      /*IF cKunde == "@"
         ppfr->Kunde := ""
      ELSE
         ppfr->Kunde := cKunde
      ENDIF*/
      ppfr->(dbUnLock())
      Aadd(aList,{oArt:Artikelnr,nLief})
      Set(_SET_DELETED,.T.)
   RETURN NIL

   STATIC FUNCTION _AddEntry(hArt,nArtnr)
      IF ! nArtnr $ hArt
         hArt[nArtnr] := {"QTY"=>0,"USR"=>0,"AUFTRAG"=>.F.,"KUNDE"=>0,"LIEF"=>0}
      ENDIF
   RETURN hArt