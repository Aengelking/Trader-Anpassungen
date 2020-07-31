#include 'y:\hb32\include\inkey.ch'
#include 'y:\harbour\trader\source\include\trget.ch'

LOCAL hTypes,cBeleg
LOCAL oBrowse
LOCAL cWA
LOCAL hValues := {=>},nValue
LOCAL cTypes := " VERBRAUCH SCHROTT SCHWUND ERSTMUSTER FERT.ALLG. ENTWICKLUNG "

NetUse("engabg","abg")
NetUse("artikel","art")
NetUse("muster","mus")
NetUse("lagerne","lne")
NetUse("werkauf","wer")
NetUse("werks","we")

abg->(dbSetOrder( 5 ))
abg->(dbSetFilter( {|| abg->Buart == "ABG" .OR. (abg->BuArt == "ENT" .AND. abg->Besnr == 0) }, 'Buart == "ABG" .OR. (BuArt == "ENT" .AND. Besnr == 0)' ))
abg->(dbSeek( Dtos(Date()-365), .T. ))

Head("Abgangstypen korrigieren")

DO WHILE ! abg->(EOF())
   art->(dbSetOrder( 2 ))
   art->(dbSeek( Str(abg->Artikelnr,6) ))
   IF abg->BuArt == "ABG"
      IF Empty(abg->Beleg)
         cBeleg := ""
         IF AT("KARTON",abg->Matchcode) == 1 .OR. AT("PACKBAND",abg->Matchcode) == 1 .OR. AT("BEUTEL",abg->Matchcode) == 1 .OR. AT("KNUELL",abg->Matchcode) == 1 .OR. AT("VERSANDTASCHE",abg->Matchcode) == 1 .OR. AT("LUFTKISSEN",abg->Matchcode) == 1
            cBeleg := "VERBRAUCH"
         //ELSEIF abg->
         ENDIF
         IF ! Empty(cBeleg)
            abg->(Rec_Lock())
            abg->Beleg := cBeleg
            abg->(dbUnLock())
         ENDIF
      ENDIF
      oArt := Artikel():New()
      nValue := oArt:GetAvgBuyPrice(abg->Transdate)
      ? abg->Beleg,abg->Matchcode,oArt:Matchcode,Transform(abg->Menge,Me(oArt:Me)),nValue
      cType := Trim(abg->Beleg)
      IF " "+Trim(abg->Beleg)+" " $ cTypes
      ELSE
         cType := "SONSTIGES"
      ENDIF
      IF ! HHasKey(hValues,cType)
         hValues[cType] := 0
      ENDIF
      hValues[cType] += abg->Menge*nValue

      IF " "+Trim(abg->Beleg)+" " $ cTypes

      ELSEIF " "+Upper(Trim(abg->Beleg))+" " $ " SCHROTT SCHWUND ERSTMUSTER "
         abg->(Rec_Lock())
         abg->Beleg := Upper(abg->Beleg)
         abg->(dbUnLock())
      ELSEIF Trim(abg->Beleg) == "FERTIGUNG" .AND. abg->Besnr != 0
         we->(dbSetOrder( 2 ))
         IF wer->(dbSeek( Str(abg->Besnr,6) )) .AND. we->(dbSeek( Str(abg->Besnr,6)+Str(art->Artikelnr,6) ))
/*            ? abg->Transdate,abg->Besnr,art->Matchcode,abg->Menge,we->Matchcode,we->Aufno
            we->(Rec_Lock())
            we->Qty -= abg->Menge
//            we->BookQty += abg->Menge
            we->(dbUnLock())*/
         ENDIF
      ELSEIF Len(aRegex := HB_Regex("[WF]A\s*([0-9]{4})",abg->Beleg)) != 0
            ? abg->Transdate,abg->BuArt,abg->Matchcode,Pad(Transform(abg->Menge,Me(art->Me)),12),abg->Beleg
            ? ValToPrg(aRegex)
            cWA := PadL(Trim(aRegex[2]),6)
            //here we will update the werkauf file and set besnr, we can re-use this code in lagabg later
            IF wer->(dbSeek( cWA ))
               IF wer->Status >= 3
                  we->(dbSetOrder( 2 ))
                  IF we->(dbSeek( cWA+Str(art->Artikelnr,6) ))
                     ? "Part on list"
                     IF abg->Besnr == 0
                        we->(Rec_Lock())
                        we->Qty += abg->Menge
                        we->(dbUnLock())
                     ENDIF

                     abg->(Rec_Lock())
                     IF abg->Besnr == 0
                        abg->Besnr := Val(cWA)
                     ENDIF
                     abg->Beleg  := "FERTIGUNG"
                     abg->BesPos := 0
                     abg->(dbUnLock())
                  ELSE
                     ? "New part"

                  ENDIF
               ELSE
                  ? "WA not booked yet"
               ENDIF
            ELSE
               ?? "WA not found"
            ENDIF
         ENDIF
   ELSEIF abg->Besnr == 0 .AND. ! mus->(dbSeek( Val(abg->Beleg) )) //besnr is used for the WA Nr. or by returns the PO, so this is neither for production nor samples
      lne->(dbSeek( Val(abg->Beleg) ))
//      ? abg->Transdate,abg->Matchcode,Pad(Transform(abg->Menge,Me(art->Me)),12),lne->Zweck
   ENDIF
   abg->(dbSkip())
ENDDO

CLS
FOR EACH nValue IN hValues
   ? Pad(nValue:__eNumKey(),15),Str(nValue,12,2)
NEXT

SInkey(0)

oBrowse := abg->(TBrowseTr():New(00,00,MaxRow(),MaxCol()))
oBrowse:NewColumn("Datum   "+Pad("Artikel",25)+" "+PadL("Menge",12)+" Beleg",{||
//    DToC(abg->Transdate)+" "+abg->Matchcode+" "+Pad(Transform(abg->Menge,Me(art->Me)),12)+" "+lne->Zweck
   art->(dbSetOrder( 2 ))
   art->(dbSeek( Str(abg->Artikelnr,6) ))
   RETURN DToC(abg->Transdate)+" "+abg->Matchcode+" "+PadL(Transform(abg->Menge,Me(art->Me)),12)+" "+abg->Beleg
})
oBrowse:ForBlock := {|| abg->Buart == "ABG" .AND. abg->Besnr == 0 .AND. ! " "+Trim(abg->Beleg)+" " $ cTypes }
oBrowse:cFor     := 'Buart == "ABG" .AND. Besnr == 0 .AND. ! " "+Trim(abg->Beleg)+" " $ "'+cTypes+'"'
abg->(dbSetFilter(oBrowse:ForBlock,oBrowse:cFor))
abg->(dbSeek( Dtos(Date()-365), .T. ))

oBrowse:AddKey(K_ESC,{|| .F. })
oBrowse:AddKey(K_F8,{|| art->(dbSetORder(2)), art->(dbSeek(Str(abg->Artikelnr,6))), ArtFo() })
oBrowse:AddKey(K_ENTER,{|| EditAbgType() })
oBrowse:EventLoop()

FUNCTION EditABGType
   MEMVAR c_five
   LOCAL cScreen := SaveScreen()
   LOCAL cCol    := SetColor(c_five)
   LOCAL nHeight := 5
   LOCAL nTop    := (MaxRow()-nHeight)/2
   LOCAL nWidth  := 30
   LOCAL nLeft   := (MaxCol()-nWidth)/2
   LOCAL oArt    := Artikel():new()
   LOCAL hGrund  := Get_ArtAbgGruende(oArt)
   LOCAL cGrund  := HGetKeyAt(hGrund,1)
   LOCAL lDummy  := .T.,lSave := .F.
   LOCAL nWA

   art->(dbSetOrder( 2 ))
   art->(dbSeek( Str(abg->Artikelnr,6) ))

   oArt    := Artikel():new()
   hGrund  := Get_ArtAbgGruende(oArt)

   @ nTop,nLeft CLEAR TO nTop+nHeight,nLeft+nWidth
   @ nTop,nLeft TO nTop+nHeight,nLeft+nWidth

   @ nTop+1,nLeft+2 SAY "Wert: "+LTrim(Str(abg->Menge*oArt:GetAvgBuyPrice(abg->Transdate),12,2))

   @ nTop+2,nLeft+2 SAY "Grund"
   @ nTop+2,nLeft+2,nTop+20,nLeft+28 GET cGrund LISTBOX hGrund ASSOCIATIVE
   @ nTop+3,nlEft+2 GET lDummy PUSHBUTTON CAPTION "OK" STATE {|| lSave := .T., ReadKill(.T.) }
   @ nTop+4,nLeft+2 GET lDummy PUSHBUTTON CAPTION "Abbrechen" STATE ReadKill(.T.)
   READ
   IF lSave
      IF Trim(cGrund) == "FA"
         nWA := GetBox(0,"Fertigungsauftrag","999999")
         IF LastKey() == K_ESC
            RETURN .T.
         ENDIF
         IF ! wer->(dbSeek( Str(nWA,6) ))
            Tr_MsgBox("Fertigungsauftrag nicht gefunden!")
            RETURN .T.
         ELSEIF wer->Status < 3
            Tr_MsgBox("Fertigungsauftrag noch nicht in Produktion!")
            RETURN .T.
         ELSE
            lSave := .F.
            we->(dbSetOrder( 2 ))
            IF we->(dbSeek( Str(nWA,6)+Str(art->Artikelnr,6) ))
               we->(Rec_Lock())
               we->BookQty += abg->Menge
               we->(dbUnLock())

               lSave := .T.
            ELSEIF Tr_MsgBox(t("Artikel noch nicht auf der Stückliste"),,{t("hinzufügen"),"abbrechen"}) == 1
               we->(dbSetOrder( 4 ))
               nPos := 1
               DO WHILE we->(dbSeek( Str(nWA,6)+Str(nPos,6) )) .AND. nPos <= 999
                  nPos++
               ENDDO
               IF nPos > 999
                  Tr_MsgBox(t("Kann nicht eingefügt werden"))
                  RETURN .T.
               ENDIF
               Alert(Str(nPos))
               we->(Add_Rec(0))
               we->aufno     := nWA
               we->listart   := wer->Artno
               we->partart   := abg->Artikelnr
               we->matchcode := abg->matchcode
               we->pos       := nPos
//               we->qty       := abg->Menge
               we->BookQty   := abg->Menge
               we->me        := art->me
               we->factor    := 1
               we->(dbUnlock())
               lSave := .T.
            ENDIF
            IF lSave
               abg->(Rec_Lock())
               abg->Beleg := "FERTIGUNG"
               abg->Besnr := nWA
               abg->BesPos := 0
               abg->(dbUnLock())
            ENDIF
         ENDIF
         RETURN .T.
      ENDIF
      abg->(Rec_Lock())
      abg->Beleg := cGrund
      abg->(dbUnlock())
      RETURN .T.
   ENDIF

RETURN .T.


FUNCTION Get_ArtAbgGruende(oArt)  //move this to a hook at a later stage
   hGruende := {"SCHWUND"=>"Schwund","SCHROTT"=>"Schrott","FA"=>"Fertigungsauftrag","ERSTMUSTER"=>"Erstmuster","ENTWICKLUNG"=>"Entwicklung","FERT.ALLG."=>"Fertigung allgemein"}
   IF Trim(oArt:Type) $ "VERP"
      hGruende["VERBRAUCH"] := "Verbrauch"
   ENDIF
RETURN hGruende
