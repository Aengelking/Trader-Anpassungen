*:*********************************************************************
*: frame_stock.prg  -  RUN_FRAME_STOCK
*:
*: Schreibt die Tabelle liefstock (Lieferantenbestand, den ein Lieferant
*: fuer uns haelt) aus den OFFENEN RAHMENBESTELLUNGEN - aber nur fuer
*: Lieferanten, die per ExtraData-Flag STOCKSFRAMES als "lagert Ware fuer
*: Rahmen" markiert sind.
*:
*: Damit fliesst die Rahmen-Deckung ueber EINE Quelle (liefstock) sowohl
*: in die frepple-Planung (Stocking-Supplier) als auch in den checkstock-
*: Deckungscheck (ArtFrameStock). Spekulativer Distributor-Bestand (z.B.
*: Waldom, ueber eigenen API-Feed) bleibt unberuehrt, solange der
*: Lieferant NICHT geflaggt ist.
*:
*: Ein Rahmen zaehlt erst, sobald der ERSTE Abruf (geplant oder geliefert)
*: existiert - dann produziert/haelt der Lieferant die Menge. Ohne Abruf
*: wird nichts geschrieben. Die Menge steht ab DelTime zur Verfuegung:
*: (Wochen bis erster Abruf, min 0) + ShipTime.
*:
*: WICHTIG: Fuer geflaggte Lieferanten "besitzt" dieser Job deren
*: liefstock-Saetze (schreibt/nullt sie). Lieferanten mit externem Feed
*: (Waldom) daher NICHT flaggen.
*:*********************************************************************

FUNCTION RUN_FRAME_STOCK()
   LOCAL hSup := {=>}          //Key: 8-stelliger Lieferant-Code -> .T.
   LOCAL hFrame := {=>}        //Key: "<Liefma8>|<Artikelnr>" -> { Menge, ShipTime, ersteAbrufKW }
   LOCAL nId, cLief, cKey, oVal, nArtnr, nFirst
   LOCAL nCurWeek := CWeek(Date())
   LOCAL nWrote := 0, nCleared := 0, nSup := 0

   NetUse("engbes","bes",.F.,0)
   NetUse("engkund","ku",.F.,0)
   NetUse("liefstock","lsto",.F.,0)

   //Feld einmalig sicherstellen (idempotent) - danach im Lieferanten-
   //ExtraData-Editor sichtbar und pro Lieferant setzbar.
   ku->(ExtraData():New(0)):Create("STOCKSFRAM","Lagert Ware fuer Rahmen","L",.F.)

   //Geflaggte Lieferanten sammeln: Nummer -> Kunde-Code (8-stellig gepaddet)
   ku->(dbSetOrder(8))   //nach Nummer
   FOR EACH nId IN GetIdsWithExtraField("KU","STOCKSFRAM")
      IF ku->(dbSeek(Str(nId,6))) .AND. ku->Group == "L"
         hSup[Pad(Trim(ku->Kunde),8)] := .T.
         nSup++
      ENDIF
   NEXT

   IF Empty(hSup)
      IF ! GetConfigValue("BATCHMODE")
         ? "Keine Lieferanten mit STOCKSFRAM markiert - nichts zu tun."      
         Sinkey(0)
      ENDIF
      RETURN NIL
   ENDIF

   //Offene Rahmen der geflaggten Lieferanten je (Lieferant, Artikel) summieren
   bes->(dbSetOrder(2))   //nach Liefma
   FOR EACH cLief IN HB_HKeys(hSup)
      bes->(dbSeek(cLief))
      DO WHILE bes->Liefma == cLief .AND. ! bes->(EOF())
         IF bes->Rahmen .AND. bes->BeStat < 3 .AND. bes->BeQty > bes->GelQty
            //Gate: die Rahmenmenge steht erst zur Verfuegung, wenn der erste
            //Abruf (geplant oder geliefert) existiert - erst dann produziert/
            //haelt der Lieferant die Vertragsmenge. nFirst = fruehester Abruf-
            //termin, 0 = noch kein Abruf -> ueberspringen.
            nFirst := FrameFirstCallOff(bes->Besnr, bes->Posnr, nCurWeek)
            IF nFirst != 0
               cKey := cLief + "|" + LTrim(Str(bes->Artikelnr))
               IF HB_HHasKey(hFrame,cKey)
                  hFrame[cKey][1] += bes->BeQty - bes->GelQty
                  hFrame[cKey][2] := Min(hFrame[cKey][2], bes->ShipTime)
                  hFrame[cKey][3] := Min(hFrame[cKey][3], nFirst)
               ELSE
                  hFrame[cKey] := { bes->BeQty - bes->GelQty, bes->ShipTime, nFirst }
               ENDIF
            ENDIF
         ENDIF
         bes->(dbSkip())
      ENDDO
   NEXT

   //liefstock aus den aggregierten Rahmenmengen schreiben
   //Stock = offene Rahmen-Restmenge, DelTime = ShipTime(Wochen) * 7 Tage
   FOR EACH oVal IN hFrame
      cKey   := oVal:__enumKey()
      cLief  := Left(cKey,8)
      nArtnr := Val(SubStr(cKey,10))
      IF lsto->(dbSeek( cLief + Str(nArtnr,6) ))
         lsto->(Rec_Lock())
      ELSE
         lsto->(Add_Rec())
         lsto->Liefma    := cLief
         lsto->Artikelnr := nArtnr
      ENDIF
      //Die Rahmenmenge ist NICHT sofort verfuegbar - sie kommt erst nach einem
      //Abruf (ShipTime). Daher Stock (=ab jetzt verfuegbar) = 0 und die ganze
      //Menge als DelQty (=verfuegbar ab DelTime Tagen). frepple modelliert das
      //als Bucket-Kapazitaet 0 bis Date()+DelTime, danach DelQty; checkstock
      //rechnet mit Stock+DelQty als deckbarer Menge und DelTime als Lieferzeit.
      lsto->Stock   := 0
      //verfuegbar ab: Wochen bis zum ersten Abruf (min 0, falls schon vorbei)
      //plus ShipTime, in Tagen. So wie es checkstock frueher gerechnet hat.
      lsto->DelTime := (Max(0, WeeksBetween(nCurWeek, oVal[3])) + oVal[2]) * 7
      lsto->DelQty  := oVal[1]
      lsto->(dbUnLock())
      nWrote++
   NEXT

   //Aufraeumen: liefstock-Saetze geflaggter Lieferanten ohne offenen Rahmen nullen
   lsto->(dbSetOrder(1))   //Liefma + Artikelnr
   FOR EACH cLief IN HB_HKeys(hSup)
      lsto->(dbSeek(cLief))
      DO WHILE lsto->Liefma == cLief .AND. ! lsto->(EOF())
         cKey := cLief + "|" + LTrim(Str(lsto->Artikelnr))
         IF ! HB_HHasKey(hFrame,cKey) .AND. lsto->Stock != 0
            lsto->(Rec_Lock())
            lsto->Stock  := 0
            lsto->DelQty := 0
            lsto->(dbUnLock())
            nCleared++
         ENDIF
         lsto->(dbSkip())
      ENDDO
   NEXT

   IF ! GetConfigValue("BATCHMODE")
      ? "RUN_FRAME_STOCK fertig:", nSup, "Lieferant(en),", nWrote, "geschrieben,", nCleared, "genullt."
      Sinkey(0)
   ENDIF

RETURN NIL

//FrameFirstCallOff(nContractNo,nContractPos,nCurWeek)
//
//Frueheste KW eines aktiven Abrufs (engbes-Zeile mit ContrNo/ContrPos auf den
//Rahmen, Index 7 = str(contrno)+str(contrpos)); 0 wenn noch KEIN Abruf
//existiert. Abrufe ohne Termin (LTerm 0) zaehlen als aktuelle KW. Eigener
//Arbeitsbereich "besco", damit der Aufrufer-Cursor unberuehrt bleibt.
STATIC FUNCTION FrameFirstCallOff(nContractNo, nContractPos, nCurWeek)
   LOCAL nWeek := 0, nCand
   LOCAL lFound := .F.

   NetUse("engbes","besco",.F.,0)
   besco->(dbSetOrder(7))   //str(contrno,6)+str(contrpos,3)
   IF besco->(dbSeek( Str(nContractNo,6)+Str(nContractPos,3) ))
      DO WHILE besco->ContrNo == nContractNo .AND. besco->ContrPos == nContractPos .AND. ! besco->(EOF())
         IF besco->BeStat < 4 .OR. (besco->BeStat >= 6 .AND. besco->BeStat <= 8)  //aktiver Abruf, nicht geloescht/storniert
            lFound := .T.
            nCand := IF(besco->LTerm == 0, nCurWeek, besco->LTerm)
            IF nWeek == 0 .OR. nCand < nWeek
               nWeek := nCand
            ENDIF
         ENDIF
         besco->(dbSkip())
      ENDDO
   ENDIF

   IF ! lFound
      RETURN 0
   ENDIF
   IF nWeek == 0
      nWeek := nCurWeek
   ENDIF
RETURN nWeek
