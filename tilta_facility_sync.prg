/*****************************************************************************
 *  tilta_facility_sync.prg  -  RUN_TILTA_FACILITY_SYNC
 *
 *  Taeglicher Abgleich der Tilta-Kreditfazilitaeten aller Factoring-Kunden.
 *  Holt alle Fazilitaeten in einem Aufruf (GET /v1/facilities mit
 *  buyer_external_ids), vergleicht mit dem Stand des letzten Laufs und meldet
 *  die Aenderungen.
 *
 *  Gedacht ist er vor allem fuer den Uebergang PENDING -> ACTIVE (bzw.
 *  REJECTED): eine neu beantragte Fazilitaet wird von Tilta geprueft, und ohne
 *  diesen Abgleich erfaehrt niemand, wann sie nutzbar ist. Genauso wichtig ist
 *  die andere Richtung, ACTIVE -> FROZEN oder EXPIRED - dann finanziert Tilta
 *  nichts Neues mehr, und der Kreditlimit-Hook liefert nur noch den offenen
 *  Bestand.
 *
 *  Der letzte Stand liegt als JSON in export\tilta_facilities.json (zentral im
 *  Datenverzeichnis, damit der Lauf nicht an einen Rechner gebunden ist).
 *  Gemeldet wird nur, was sich geaendert hat; laeuft der Abgleich ohne
 *  Aenderung durch, gibt es keine Mail.
 *
 *  Zweiter Teil: der Finanzierungsstand der eingereichten Rechnungen. Ein 201
 *  beim Einreichen heisst nur, dass Tilta die Rechnung angenommen hat - ob
 *  tatsaechlich finanziert wird, steht im Invoice-Objekt unter services[] mit
 *  service_type FINANCING. Wichtig sind REJECTED (Ware ist raus, Geld kommt
 *  nicht), ein haengendes IN_REVIEW samt requirements (was fehlt) und PAID_OUT
 *  mit dem tatsaechlichen Vorschussbetrag nach Gebuehren.
 *
 *  Im Batchmodus laeuft alles ohne Rueckfrage, interaktiv steht das Ergebnis
 *  zusaetzlich auf dem Bildschirm.
 *****************************************************************************/

#define TILTA_SYNC_BLOCK   50      //so viele Buyer je Aufruf
#define TILTA_REVIEW_DAYS   3      //ab so vielen Tagen gilt IN_REVIEW als haengend

PROCEDURE Run_Tilta_Facility_Sync()

LOCAL aIds, aBlock := {}
LOCAL hNow := {=>}, hOld := {=>}
LOCAL aChanges := {}
LOCAL cFile := Path("export\tilta_facilities.json")
LOCAL cBody, nResponse := 0, cResponse := ""
LOCAL xList, hFac
LOCAL nX, nY, cId
LOCAL cName, cStatus, nTotal, nAvail
LOCAL lBatch := GetConfigValue("BATCHMODE")
LOCAL lFirst
LOCAL cMail, aTo
LOCAL nErrors := 0
LOCAL aInv, nRe, cRe, cSt, cFin, cReq, nAdv, cSince, cWho
LOCAL nOpen := 0, nNotSent := 0

   NetUse("engkund","ku",.F.,0)
   NetUse("rechnung","reh")

   IF ! lBatch
      Head("Tilta-Fazilitaeten abgleichen"+IF(__TiltaIsSandbox()," [SANDBOX]",""))
      SetPos(01,00)
   ENDIF

   aIds := GetIdsWithExtraField("KU","FACTORING")
   IF Len(aIds) == 0
      ? "Keine Factoring-Kunden gefunden - nichts abzugleichen."
      IF ! lBatch
         SInkey(0)
      ENDIF
      RETURN
   ENDIF
   ? "Factoring-Kunden:",LTrim(Str(Len(aIds)))

   /*  Stand des letzten Laufs  */
   IF File(cFile)
      hOld := hb_jsonDecode(MemoRead(cFile))
   ENDIF
   IF ValType(hOld) != "H"
      hOld := {=>}
   ENDIF
   lFirst := Len(hOld) == 0

   /*  Fazilitaeten blockweise holen  */
   FOR nX := 1 TO Len(aIds)
      Aadd(aBlock,LTrim(Str(aIds[nX])))
      IF Len(aBlock) >= TILTA_SYNC_BLOCK .OR. nX == Len(aIds)
         cBody := __TiltaCall("facilities?buyer_external_ids="+__TiltaJoin(aBlock,","), ;
                              "GET",NIL,@nResponse,@cResponse)
         IF nResponse != 200
            ? "FEHLER beim Abruf:","HTTP "+LTrim(Str(nResponse)),cResponse
            nErrors++
         ELSE
            xList := hb_jsonDecode(cBody)
            IF ValType(xList) == "H" .AND. HHasKey(xList,"data")
               xList := xList["data"]
            ENDIF
            IF ValType(xList) == "A"
               FOR nY := 1 TO Len(xList)
                  hFac := xList[nY]
                  IF ValType(hFac) == "H" .AND. HHasKey(hFac,"buyer_external_id")
                     hNow[ AllTrim(hFac["buyer_external_id"]) ] := ;
                        { "status" => IF(HHasKey(hFac,"status"),hFac["status"],"?"), ;
                          "total"  => IF(HHasKey(hFac,"total_amount"),hFac["total_amount"],0), ;
                          "avail"  => IF(HHasKey(hFac,"available_amount"),hFac["available_amount"],0) }
                  ENDIF
               NEXT
            ELSE
               ? "Antwort nicht lesbar:",Left(cBody,80)
               nErrors++
            ENDIF
         ENDIF
         aBlock := {}
      ENDIF
   NEXT

   IF nErrors > 0 .AND. Len(hNow) == 0
      ? "Abgleich abgebrochen - keine Daten erhalten."
      IF ! lBatch
         SInkey(0)
      ENDIF
      RETURN
   ENDIF

   /*  Vergleich: jeder Factoring-Kunde einzeln  */
   ku->(dbSetOrder( 8 ))    //str(nummer,6)
   FOR nX := 1 TO Len(aIds)
      cId := LTrim(Str(aIds[nX]))
      IF ku->(dbSeek( Str(aIds[nX],6) ))
         cName := Trim(ku->Kunde)+" "+Trim(ku->Name1)
      ELSE
         cName := "(Kunde "+cId+" nicht gefunden)"
      ENDIF

      IF HHasKey(hNow,cId)
         cStatus := hNow[cId]["status"]
         nTotal  := hNow[cId]["total"]
         nAvail  := hNow[cId]["avail"]
      ELSE
         cStatus := "-"          //keine Fazilitaet bei Tilta
         nTotal  := 0
         nAvail  := 0
         hNow[cId] := {"status"=>"-","total"=>0,"avail"=>0}
      ENDIF

      IF HHasKey(hOld,cId) .AND. ! HHasKey(hOld[cId],"status")
         HB_HDel(hOld,cId)                   //Altstand unbrauchbar, wie neu behandeln
      ENDIF
      IF ! HHasKey(hOld,cId)
         Aadd(aChanges,Pad(cName,34)+" neu: "+Pad(cStatus,8)+ ;
                       IF(cStatus == "-","(keine Fazilitaet)","Limit "+__TiltaMoney(nTotal)))
      ELSE
         IF ! (AllTrim(hOld[cId]["status"]) == AllTrim(cStatus))
            Aadd(aChanges,Pad(cName,34)+" Status "+AllTrim(hOld[cId]["status"])+" -> "+AllTrim(cStatus))
         ENDIF
         IF hOld[cId]["total"] != nTotal
            Aadd(aChanges,Pad(cName,34)+" Limit "+__TiltaMoney(hOld[cId]["total"])+" -> "+__TiltaMoney(nTotal))
         ENDIF
      ENDIF

      IF ! lBatch
         ? Pad(cName,34),Pad(cStatus,8),PadL(__TiltaMoney(nTotal),12),PadL(__TiltaMoney(nAvail),12)
         IF Row() >= MaxRow()-1
            SetPos(01,00)
         ENDIF
      ENDIF
   NEXT

   /*  Teil 2: Finanzierungsstand der eingereichten Rechnungen.
    *  Kandidaten sind die Rechnungen mit gesetztem Factorer (wie in
    *  RUN_CHECK_FACTORING). Abgefragt wird nur, was noch nicht durch ist - ein
    *  erreichtes PAID_OUT/REJECTED/SETTLED bleibt im Stand stehen und kostet
    *  keinen Aufruf mehr. Was der Kunde spaeter an Tilta zahlt, zeigt die
    *  Fazilitaet aus Teil 1, nicht diese Liste.  */
   aInv := GetIdsWithExtraField("REH","FACTORER")
   FOR nX := 1 TO Len(aInv)
      nRe := aInv[nX]
      cRe := "INV:"+LTrim(Str(nRe))
      IF HHasKey(hOld,cRe) .AND. ! HHasKey(hOld[cRe],"fin")
         HB_HDel(hOld,cRe)                   //Altstand unbrauchbar, wie neu behandeln
      ENDIF

      IF HHasKey(hOld,cRe) .AND. __TiltaFinDone(hOld[cRe]["fin"])
         hNow[cRe] := hOld[cRe]                 //erledigt, Stand uebernehmen
         LOOP
      ENDIF

      cBody := __TiltaCall("invoices/"+LTrim(Str(nRe)),"GET",NIL,@nResponse,@cResponse)
      IF nResponse == 404
         nNotSent++                             //Factorer gesetzt, aber nicht eingereicht
         LOOP
      ELSEIF nResponse != 200
         ? "FEHLER Rechnung",LTrim(Str(nRe)),"HTTP "+LTrim(Str(nResponse)),cResponse
         nErrors++
         LOOP
      ENDIF

      hFac := hb_jsonDecode(cBody)              //hier das Invoice-Objekt
      IF ValType(hFac) != "H"
         nErrors++
         LOOP
      ENDIF
      cSt  := IF(HHasKey(hFac,"status") .AND. ValType(hFac["status"]) == "C",hFac["status"],"?")
      cFin := __TiltaFinInfo(hFac,@nAdv,@cReq)
      nOpen++

      cWho := "RE "+LTrim(Str(nRe))
      IF reh->(dbSeek( Str(nRe,6) ))
         cWho += " "+Trim(reh->Kunde)
      ENDIF

      cSince := DToS(Date())
      IF HHasKey(hOld,cRe) .AND. AllTrim(hOld[cRe]["fin"]) == AllTrim(cFin)
         cSince := hOld[cRe]["since"]           //Status unveraendert, Zeitpunkt behalten
      ENDIF
      hNow[cRe] := {"st"=>cSt,"fin"=>cFin,"adv"=>nAdv,"since"=>cSince}

      IF ! HHasKey(hOld,cRe)
         Aadd(aChanges,Pad(cWho,24)+" eingereicht, Finanzierung: "+IF(Empty(cFin),"(keine Angabe)",cFin)+ ;
                       IF(Empty(cReq),""," - offen: "+cReq))
      ELSEIF ! (AllTrim(hOld[cRe]["fin"]) == AllTrim(cFin))
         Aadd(aChanges,Pad(cWho,24)+" Finanzierung "+AllTrim(hOld[cRe]["fin"])+" -> "+AllTrim(cFin)+ ;
                       IF(AllTrim(cFin) == "PAID_OUT" .AND. nAdv != 0,", ausgezahlt "+__TiltaMoney(nAdv),"")+ ;
                       IF(Empty(cReq),""," - offen: "+cReq))
      ELSEIF AllTrim(cFin) == "IN_REVIEW" .AND. Date() - SToD(cSince) >= TILTA_REVIEW_DAYS
         Aadd(aChanges,Pad(cWho,24)+" haengt seit "+LTrim(Str(Date()-SToD(cSince)))+" Tagen in IN_REVIEW"+ ;
                       IF(Empty(cReq),""," - offen: "+cReq))
      ENDIF
   NEXT

   IF ! lBatch
      ?
      ? "Rechnungen in Beobachtung:",LTrim(Str(nOpen)), ;
        IF(nNotSent > 0,"| noch nicht eingereicht: "+LTrim(Str(nNotSent)),"")
   ENDIF

   /*  Ergebnis  */
   ?
   IF Len(aChanges) == 0
      ? "Keine Aenderungen."
   ELSE
      ? "Aenderungen:",LTrim(Str(Len(aChanges)))
      FOR nX := 1 TO Len(aChanges)
         ? aChanges[nX]
      NEXT

      cMail := IF(lFirst,"Erstlauf des Abgleichs - der bisherige Stand war nicht bekannt."+Chr(13)+Chr(10)+Chr(13)+Chr(10),"")
      FOR nX := 1 TO Len(aChanges)
         cMail += aChanges[nX]+Chr(13)+Chr(10)
      NEXT
      cMail += Chr(13)+Chr(10)+"Status: ACTIVE nutzbar, PENDING in Pruefung, FROZEN eingefroren, EXPIRED abgelaufen."+Chr(13)+Chr(10)
      cMail += "Bei allem ausser ACTIVE finanziert Tilta nichts Neues; das Kreditlimit im Trader"+Chr(13)+Chr(10)
      cMail += "faellt dann auf den bereits offenen Bestand zurueck."+Chr(13)+Chr(10)

      aTo := {{"amos.engelking@engelking.de","Amos"},{"sigrid.reichmann@engelking.de","Sigrid"}}
      SendMail(aTo,"Tilta: "+LTrim(Str(Len(aChanges)))+" Aenderung(en) an den Kreditfazilitaeten",cMail)
   ENDIF

   IF nErrors > 0
      ? "Achtung:",LTrim(Str(nErrors)),"Abrufe fehlgeschlagen - Stand ggf. unvollstaendig."
   ELSE
      MemoWrit(cFile,hb_jsonEncode(hNow))     //nur bei fehlerfreiem Lauf fortschreiben
   ENDIF

   IF ! lBatch
      ? "Ende mit einer Taste"
      SInkey(0)
   ENDIF

RETURN

/*  Betrag aus Cent  */
STATIC FUNCTION __TiltaMoney(nCent)
   IF ValType(nCent) != "N"
      RETURN "?"
   ENDIF
RETURN LTrim(Transform(nCent/100,"@E 9,999,999.99"))

/*  Array zu Zeichenkette verbinden  */
STATIC FUNCTION __TiltaJoin(aList,cSep)
   LOCAL cOut := "", nX
   FOR nX := 1 TO Len(aList)
      cOut += IF(nX>1,cSep,"")+aList[nX]
   NEXT
RETURN cOut

/*  Status des FINANCING-Service aus dem Invoice-Objekt ziehen, dazu den
 *  Vorschussbetrag (nach Gebuehren) und die offenen Voraussetzungen.
 *  Laut Doku kommen services[] nur "when expanded" mit - fehlt das Feld,
 *  bleibt der Status leer statt dass es knallt.                          */
STATIC FUNCTION __TiltaFinInfo(hInv,nAdvance,cReq)
   LOCAL xServ, hS, nX

   nAdvance := 0
   cReq     := ""
   IF ValType(hInv) != "H" .OR. ! HHasKey(hInv,"services")
      RETURN ""
   ENDIF
   xServ := hInv["services"]
   IF ValType(xServ) != "A"
      RETURN ""
   ENDIF
   FOR nX := 1 TO Len(xServ)
      hS := xServ[nX]
      IF ValType(hS) == "H" .AND. HHasKey(hS,"service_type") .AND. hS["service_type"] == "FINANCING"
         IF HHasKey(hS,"advance") .AND. ValType(hS["advance"]) == "H" .AND. HHasKey(hS["advance"],"value")
            nAdvance := hS["advance"]["value"]
         ENDIF
         IF HHasKey(hS,"requirements")
            cReq := __TiltaReqText(hS["requirements"])
         ENDIF
         RETURN IF(HHasKey(hS,"status") .AND. ValType(hS["status"]) == "C",hS["status"],"")
      ENDIF
   NEXT
RETURN ""

/*  Offene Voraussetzungen als kurzer Text - die Elemente koennen Zeichenketten
 *  oder Objekte sein, deshalb defensiv.                                   */
STATIC FUNCTION __TiltaReqText(xReq)
   LOCAL cOut := "", nX, x
   IF ValType(xReq) != "A"
      RETURN ""
   ENDIF
   FOR nX := 1 TO Len(xReq)
      x := xReq[nX]
      IF ValType(x) == "C"
         cOut += IF(Empty(cOut),"",", ")+x
      ELSEIF ValType(x) == "H"
         IF HHasKey(x,"type") .AND. ValType(x["type"]) == "C"
            cOut += IF(Empty(cOut),"",", ")+x["type"]
         ELSEIF HHasKey(x,"code") .AND. ValType(x["code"]) == "C"
            cOut += IF(Empty(cOut),"",", ")+x["code"]
         ENDIF
      ENDIF
   NEXT
RETURN Left(cOut,60)

/*  Ist der Finanzierungsvorgang fuer uns abgeschlossen? Dann braucht er keinen
 *  Aufruf mehr. PAID_OUT gilt als erledigt: das Geld ist da. Was der Kunde
 *  danach an Tilta zahlt, zeigt die Fazilitaet.                           */
STATIC FUNCTION __TiltaFinDone(cFin)
   LOCAL aDone := {"PAID_OUT","SETTLED","REJECTED","CANCELLED","COLLECTED", ;
                   "CLAIM_PAID","CLAIM_DENIED","UNCOLLECTIBLE","COVER_EXPIRED"}
   LOCAL nX
   IF ValType(cFin) != "C" .OR. Empty(cFin)
      RETURN .F.
   ENDIF
   FOR nX := 1 TO Len(aDone)
      IF aDone[nX] == AllTrim(cFin)
         RETURN .T.
      ENDIF
   NEXT
RETURN .F.

#include "x:\run\tilta_api.prg"
