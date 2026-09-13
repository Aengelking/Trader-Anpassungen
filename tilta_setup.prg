/*****************************************************************************
 *  tilta_setup.prg  -  Run_Tilta_Setup(nKuNr)
 *
 *  Richtet einen Kunden bei Tilta ein: Buyer anlegen, Ansprechpartner melden,
 *  Kreditfazilitaet beantragen. Laeuft ohne Rueckfragen und ist idempotent -
 *  was es schon gibt, wird nicht angefasst.
 *
 *  Aufgerufen wird es an zwei Stellen:
 *    - Hook after_save_address, sobald ein Kunde auf Factoring steht
 *    - RUN_TILTA_BUYER, wenn jemand es von Hand anstoesst
 *  Deshalb steht hier die Logik und dort nur die Oberflaeche.
 *
 *  Alle Textfelder gehen durch hb_StrToUtf8(): die Quelle ist CP865, der
 *  JSON-Body muss UTF-8 sein - sonst kommen Umlaute bei Tilta falsch an.
 *
 *  Rueckgabe: Hash mit
 *     "ok"      .T. wenn am Ende eine Fazilitaet existiert oder beantragt ist
 *     "changed" .T. wenn etwas angelegt wurde (fuer Protokoll/Meldung)
 *     "status"  Status der Fazilitaet, soweit bekannt
 *     "log"     Array mit Klartextzeilen zum Anzeigen oder Protokollieren
 *****************************************************************************/

FUNCTION Run_Tilta_Setup(nKuNr)

LOCAL hRes := {"ok" => .F., "changed" => .F., "status" => "", "log" => {}}
LOCAL cBuyer, cForm
LOCAL cBody, nResponse := 0, cResponse := ""
LOCAL hSend, aIdent := {}
LOCAL hContact
LOCAL cName, nPos
LOCAL xList
LOCAL hFac
LOCAL nGood

   NetUse("engkund","ku",.F.,0)
   NetUse("skontoa","ska",.F.,0)
   ku->(dbSetOrder( 8 ))                       //str(nummer,6)
   IF ! ku->(dbSeek( Str(nKuNr,6) ))
      Aadd(hRes["log"],"Kunde "+LTrim(Str(nKuNr))+" nicht gefunden.")
      RETURN hRes
   ENDIF

   cBuyer := LTrim(Str(ku->Nummer))
   cForm  := __TiltaLegalForm(ku->CompForm)
   Aadd(hRes["log"],"Umgebung: "+IF(__TiltaIsSandbox(),"SANDBOX","Produktion"))

   /*  Factoring geht nur ohne Skonto. Der Hook after_save_address stellt die
    *  Zahlungsbedingung dafuer um; das hier ist die Sicherung, falls ein Kunde
    *  auf anderem Weg auf Factoring landet.  */
   IF __TiltaHasSkonto(ku->Skonto,Date())
      Aadd(hRes["log"],"Zahlungsbedingung enthaelt Skonto - Factoring ist nur ohne Skonto moeglich. Erst umstellen.")
      RETURN hRes
   ENDIF

   /*  1. Buyer  */
   __TiltaCall("buyers/"+cBuyer,"GET",NIL,@nResponse,@cResponse)
   IF nResponse == 200
      Aadd(hRes["log"],"Buyer "+cBuyer+" ist vorhanden.")
   ELSEIF nResponse != 404
      Aadd(hRes["log"],"Buyer-Abfrage fehlgeschlagen: HTTP "+LTrim(Str(nResponse))+" "+cResponse)
      RETURN hRes
   ELSE
      IF ! Empty(ku->VatNr)
         Aadd(aIdent,{"type"    => "VAT_ID", ;
                      "value"   => hb_StrToUtf8(StrTran(Trim(ku->VatNr)," ","")), ;
                      "country" => Trim(ku->CountryIso)})
      ENDIF
      IF ! Empty(ku->CompNo)
         Aadd(aIdent,{"type"    => "REGISTER_ID", ;
                      "value"   => hb_StrToUtf8(Trim(ku->CompNo)), ;
                      "country" => Trim(ku->CountryIso)})
      ENDIF

      hSend := {=>}
      hSend["external_id"]      := cBuyer
      hSend["legal_name"]       := hb_StrToUtf8(AllTrim(Trim(ku->Name1)+" "+Trim(ku->Name2)))
      hSend["legal_form"]       := cForm
      hSend["business_address"] := {"country"  => Trim(ku->CountryIso), ;
                                    "postcode" => hb_StrToUtf8(Trim(ku->PLZ)), ;
                                    "city"     => hb_StrToUtf8(Trim(ku->Town)), ;
                                    "street"   => hb_StrToUtf8(Trim(ku->Street))}
      IF Len(aIdent) > 0
         hSend["business_identifiers"] := aIdent   //USt-Id und HR-Nummer helfen bei der Bonitaet
      ENDIF

      TxtBox("Tilta: Buyer wird angelegt...")
      cBody := __TiltaCall("buyers","POST",hSend,@nResponse,@cResponse)
      TxtClear()
      IF nResponse < 200 .OR. nResponse >= 300
         Aadd(hRes["log"],"Buyer konnte nicht angelegt werden: HTTP "+LTrim(Str(nResponse))+" "+cResponse+" "+Left(cBody,120))
         RETURN hRes
      ENDIF
      hRes["changed"] := .T.
      Aadd(hRes["log"],"Buyer "+cBuyer+" angelegt ("+cForm+").")
   ENDIF

   /*  2. Ansprechpartner - ohne ihn lehnt Tilta die Fazilitaet ab
    *     (INSUFFICIENT_BUYER_INFO / "No buyer contact")  */
   cBody := __TiltaCall("buyers/"+cBuyer+"/contacts","GET",NIL,@nResponse,@cResponse)
   xList := NIL
   IF nResponse == 200
      xList := hb_jsonDecode(cBody)
      IF ValType(xList) == "H" .AND. HHasKey(xList,"data")
         xList := xList["data"]
      ENDIF
   ELSEIF nResponse != 404
      Aadd(hRes["log"],"Kontakte konnten nicht gelesen werden: HTTP "+LTrim(Str(nResponse))+" "+cResponse)
   ENDIF

   IF ! (ValType(xList) == "A" .AND. Len(xList) > 0)
      hContact := GetAccountsContact(ku->Nummer)
      IF hContact == NIL
         hContact := GetInvoiceContact(ku->Nummer)
      ENDIF
      IF hContact == NIL .OR. Empty(hContact["email"])
         Aadd(hRes["log"],"Kein Buchhaltungs- oder Rechnungskontakt mit E-Mail hinterlegt - Tilta braucht einen Ansprechpartner.")
         RETURN hRes
      ENDIF

      cName := AllTrim(hContact["name"])
      nPos  := RAt(" ",cName)

      hSend := {=>}                               //hier: der Kontakt
      hSend["buyer_external_id"] := cBuyer
      IF nPos > 0
         hSend["first_name"] := hb_StrToUtf8(Left(cName,nPos-1))
         hSend["last_name"]  := hb_StrToUtf8(SubStr(cName,nPos+1))
      ELSE
         hSend["last_name"]  := hb_StrToUtf8(cName)
      ENDIF
      hSend["email"] := hb_StrToUtf8(Trim(hContact["email"]))
      IF hContact["id"] != 0
         hSend["external_id"] := LTrim(Str(hContact["id"]))
      ENDIF

      TxtBox("Tilta: Ansprechpartner wird angelegt...")
      cBody := __TiltaCall("contacts","POST",hSend,@nResponse,@cResponse)
      TxtClear()
      IF nResponse < 200 .OR. nResponse >= 300
         Aadd(hRes["log"],"Ansprechpartner konnte nicht angelegt werden: HTTP "+LTrim(Str(nResponse))+" "+cResponse+" "+Left(cBody,120))
         RETURN hRes
      ENDIF
      hRes["changed"] := .T.
      Aadd(hRes["log"],"Ansprechpartner gemeldet: "+cName+" <"+Trim(hContact["email"])+">")
   ENDIF

   /*  3. Fazilitaet. Beantragt wird das intern genehmigte Kreditlimit; als
    *  Bestandskunde gilt, wer mindestens zwei Rechnungen nicht spaeter als
    *  30 Tage nach Faelligkeit bezahlt hat.  */
   cBody := __TiltaCall("buyers/"+cBuyer+"/facility","GET",NIL,@nResponse,@cResponse)
   IF nResponse == 404
      nGood := __TiltaGoodPayments(ku->Kunde)
      hSend := {=>}
      IF ku->CredLimit > 0
         hSend["requested_amount"]   := Round(ku->CredLimit*100,0)
         hSend["requested_currency"] := "EUR"
      ENDIF
      hSend["is_existing_buyer"] := nGood >= 2

      TxtBox("Tilta: Fazilitaet wird beantragt...")
      cBody := __TiltaCall("buyers/"+cBuyer+"/facility","POST",hSend,@nResponse,@cResponse)
      TxtClear()
      IF nResponse < 200 .OR. nResponse >= 300
         Aadd(hRes["log"],"Fazilitaet wurde nicht angelegt: HTTP "+LTrim(Str(nResponse))+" "+cResponse+" "+Left(cBody,120))
         RETURN hRes
      ENDIF
      hRes["changed"] := .T.
      Aadd(hRes["log"],"Kreditfazilitaet beantragt"+ ;
                       IF(ku->CredLimit > 0," ueber "+__TiltaMoney(Round(ku->CredLimit*100,0)),"")+ ;
                       ", Bestandskunde: "+IF(nGood >= 2,"ja","nein")+" ("+LTrim(Str(nGood))+" puenktliche Zahlungen).")
      cBody := __TiltaCall("buyers/"+cBuyer+"/facility","GET",NIL,@nResponse,@cResponse)
   ELSEIF nResponse != 200
      Aadd(hRes["log"],"Fazilitaet konnte nicht gelesen werden: HTTP "+LTrim(Str(nResponse))+" "+cResponse)
      RETURN hRes
   ENDIF

   IF nResponse == 200
      hFac := hb_jsonDecode(cBody)
      IF ValType(hFac) == "H"
         hRes["status"] := IF(HHasKey(hFac,"status") .AND. ValType(hFac["status"]) == "C",hFac["status"],"?")
         Aadd(hRes["log"],"Fazilitaet: Status "+hRes["status"]+ ;
                          IF(HHasKey(hFac,"total_amount")," , Limit "+__TiltaMoney(hFac["total_amount"]),"")+ ;
                          IF(HHasKey(hFac,"available_amount")," , verfuegbar "+__TiltaMoney(hFac["available_amount"]),""))
         hRes["ok"] := .T.
      ENDIF
   ENDIF

RETURN hRes

/*  Enthaelt die Zahlungsbedingung ein Skonto? GetSkonto() liefert JEDE Stufe
 *  als {Rate,Tage} zurueck, also auch "30 Tage netto" mit Rate 0 - es zaehlt
 *  daher nur eine Stufe mit Rate ungleich 0.                              */
STATIC FUNCTION __TiltaHasSkonto(nSkonto,dDate)
   LOCAL aSk := ska->(GetSkonto(nSkonto,dDate,dDate))
   LOCAL nX
   FOR nX := 1 TO Len(aSk)
      IF ValType(aSk[nX]) == "A" .AND. Len(aSk[nX]) >= 1 .AND. aSk[nX][1] != 0
         RETURN .T.
      ENDIF
   NEXT
RETURN .F.

/*  Anzahl der Rechnungen, die nicht spaeter als 30 Tage nach Faelligkeit
 *  bezahlt wurden - das ist unser Kriterium fuer is_existing_buyer.
 *  Faelligkeit wie ueberall im Trader: Rechnungsdatum + GetSkontoWait().    */
STATIC FUNCTION __TiltaGoodPayments(cKunde)
   LOCAL nCount := 0
   LOCAL aEnv := SaveEnv()
   LOCAL dDue, lPaid

   cKunde := Pad(cKunde,8)
   NetUse("englsre","re",.F.,0)
   NetUse("skontoa","ska",.F.,0)
   re->(dbSetOrder( 2 ))                        //str(reposnr,3)+kunde
   IF re->(dbSeek( Str(0,3)+cKunde ))
      DO WHILE ! re->(Eof()) .AND. re->RePosnr == 0 .AND. re->Kunde == cKunde
         lPaid := re->Code == 3 .OR. re->Status != 0 .OR. re->PosWt <= re->AoQty
         IF lPaid .AND. re->PosWt > 0 .AND. ! Empty(re->PayDate)
            dDue := re->RechDat + ska->(GetSkontoWait(re->Skonto,re->RechDat))
            IF re->PayDate <= dDue + 30
               nCount++
            ENDIF
         ENDIF
         re->(dbSkip())
      ENDDO
   ENDIF
   RestEnv(aEnv,.F.)
RETURN nCount

/*  Rechtsform aus dem Trader-Schluessel auf die Tilta-Werte abbilden:
 *  LIMITED_COMPANY, SOLE_TRADER, PARTNERSHIP, PUBLIC_COMPANY, COOPERATIVE,
 *  GOVERNMENT, OTHER. Unbekanntes wird OTHER.                             */
STATIC FUNCTION __TiltaLegalForm(cCompForm)
   LOCAL cF := Upper(AllTrim(cCompForm))
   DO CASE
   CASE cF == "GMBH" .OR. cF == "UG" .OR. cF == "LTD"
      RETURN "LIMITED_COMPANY"
   CASE cF == "AG" .OR. cF == "SE" .OR. cF == "KGAA"
      RETURN "PUBLIC_COMPANY"
   CASE cF == "EK"
      RETURN "SOLE_TRADER"
   CASE cF == "KG" .OR. cF == "OHG" .OR. cF == "GBR"
      RETURN "PARTNERSHIP"
   CASE cF == "EG"
      RETURN "COOPERATIVE"
   CASE cF == "KOER" .OR. cF == "STIFT"
      RETURN "GOVERNMENT"
   ENDCASE
RETURN "OTHER"

/*  Betrag aus Cent  */
STATIC FUNCTION __TiltaMoney(nCent)
   IF ValType(nCent) != "N"
      RETURN "?"
   ENDIF
RETURN LTrim(Transform(nCent/100,"@E 9,999,999.99"))

#include "x:\run\tilta_api.prg"
