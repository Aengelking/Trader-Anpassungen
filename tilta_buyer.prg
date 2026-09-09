/*****************************************************************************
 *  tilta_buyer.prg  -  RUN_TILTA_BUYER
 *
 *  Richtet einen Kunden bei Tilta ein: Buyer anlegen und die Kreditfazilitaet
 *  beantragen. Das gehoert zur Umstellung eines Kunden auf Factoring, nicht
 *  zum Einreichen einer Rechnung - RUN_TILTA_INVOICE setzt voraus, dass das
 *  hier bereits gelaufen ist.
 *
 *  Spaeter soll das automatisch beim Setzen des Factoring-Kennzeichens
 *  passieren (Hook after_save_address). Der Ablauf hier ist dafuer schon
 *  idempotent: existiert der Buyer, wird nichts angelegt, sondern nur der
 *  Stand angezeigt.
 *
 *  Pflichtfelder laut Tilta: external_id, legal_name, legal_form,
 *  business_address (postcode, city, country).
 *****************************************************************************/

PROCEDURE Run_Tilta_Buyer()

LOCAL cKunde := Space(8)
LOCAL getList := {}
LOCAL cBuyer, cForm
LOCAL hBuyer, aIdent := {}
LOCAL cBody, nResponse := 0, cResponse := ""
LOCAL oExtra

   NetUse("engkund","ku",.F.,0)

   Head("Kunde bei Tilta einrichten"+IF(__TiltaIsSandbox()," [SANDBOX]",""))

   /*  Kunde waehlen  */
   DO WHILE .T.
      @ 01,00 SAY "Kunde" GET cKunde PICTURE "@!"
      READ
      IF LastKey() == 27
         RETURN
      ENDIF
      @ 01,14 CLEAR TO 01,MaxCol()
      ku->(dbSetOrder( 1 ))
      IF ! ku->(dbSeek( Pad(cKunde,8)+"K" ))
         @ 01,14 SAY "NICHT GEFUNDEN"
      ELSE
         @ 01,14 SAY Trim(ku->Name1)+" "+Trim(ku->Name2)
         EXIT
      ENDIF
   ENDDO

   cBuyer := LTrim(Str(ku->Nummer))
   cForm  := __TiltaLegalForm(ku->CompForm)

   oExtra := ku->(ExtraData():New(ku->Nummer))
   IF ! oExtra:Factoring
      IF Tr_MsgBox({"Dieser Kunde ist im Trader nicht auf Factoring gestellt.","Trotzdem bei Tilta einrichten?"},,{"Nein","Ja"}) != 2
         RETURN
      ENDIF
   ENDIF

   /*  Gibt es den Buyer schon?  */
   cBody := __TiltaCall("buyers/"+cBuyer,"GET",NIL,@nResponse,@cResponse)
   IF nResponse == 200
      Tr_MsgBox({"Kunde ist bei Tilta bereits als Buyer "+cBuyer+" angelegt.", ;
                 "Der Stammsatz bleibt unveraendert, geprueft wird nur die Fazilitaet."},"HINWEIS")
      __TiltaEnsureFacility(cBuyer)
      RETURN
   ELSEIF nResponse != 404
      Tr_MsgBox({"Unerwartete Antwort von Tilta: HTTP "+LTrim(Str(nResponse))+" "+cResponse,Left(cBody,200)},"FEHLER")
      RETURN
   ENDIF

   /*  Buyer anlegen  */
   IF Tr_MsgBox({Trim(ku->Name1)+" "+Trim(ku->Name2), ;
                 Trim(ku->PLZ)+" "+Trim(ku->Town)+", "+Trim(ku->CountryIso), ;
                 "Rechtsform: "+cForm, ;
                 "als Buyer "+cBuyer+" bei Tilta anlegen?"},IF(__TiltaIsSandbox(),"SANDBOX",""),{"Nein","Ja"}) != 2
      RETURN
   ENDIF

   IF ! Empty(ku->VatNr)
      Aadd(aIdent,{"type"=>"VAT_ID","value"=>StrTran(Trim(ku->VatNr)," ",""),"country"=>Trim(ku->CountryIso)})
   ENDIF
   IF ! Empty(ku->CompNo)
      Aadd(aIdent,{"type"=>"REGISTER_ID","value"=>Trim(ku->CompNo),"country"=>Trim(ku->CountryIso)})
   ENDIF

   hBuyer := {=>}
   hBuyer["external_id"]      := cBuyer
   hBuyer["legal_name"]       := AllTrim(Trim(ku->Name1)+" "+Trim(ku->Name2))
   hBuyer["legal_form"]       := cForm
   hBuyer["business_address"] := {"country"  => Trim(ku->CountryIso), ;
                                  "postcode" => Trim(ku->PLZ), ;
                                  "city"     => Trim(ku->Town), ;
                                  "street"   => Trim(ku->Street)}
   IF Len(aIdent) > 0
      hBuyer["business_identifiers"] := aIdent      //USt-Id und HR-Nummer helfen bei der Bonitaet
   ENDIF

   TxtBox("Buyer wird bei Tilta angelegt...")
   cBody := __TiltaCall("buyers","POST",hBuyer,@nResponse,@cResponse)
   TxtClear()

   IF nResponse < 200 .OR. nResponse >= 300
      Tr_MsgBox({"Buyer konnte nicht angelegt werden.","HTTP "+LTrim(Str(nResponse))+" "+cResponse,Left(cBody,200)},"FEHLER")
      RETURN
   ENDIF

   Tr_MsgBox("Buyer "+cBuyer+" angelegt.","OK")
   __TiltaEnsureFacility(cBuyer)

RETURN

/*  Tilta braucht am Buyer mindestens einen Ansprechpartner, sonst wird die
 *  Fazilitaet mit INSUFFICIENT_BUYER_INFO / "No buyer contact" abgelehnt.
 *  Kontakte sind eigene Objekte: POST /v1/contacts mit buyer_external_id als
 *  einzigem Pflichtfeld (das contact_persons aus der Postman-Collection gibt
 *  es in der aktuellen API nicht mehr).
 *  Genommen wird der Buchhaltungskontakt des Kunden, ersatzweise der
 *  Rechnungskontakt. Die Telefonnummer bleibt weg: Tilta erwartet E.164,
 *  im Trader stehen gewachsene Formate.
 *  ku muss auf dem Kunden stehen.                                          */
STATIC FUNCTION __TiltaEnsureContact(cBuyer)
   LOCAL cBody, nResponse := 0, cResponse := ""
   LOCAL xList, hContact, hNew
   LOCAL cName, nPos

   cBody := __TiltaCall("buyers/"+cBuyer+"/contacts","GET",NIL,@nResponse,@cResponse)
   IF nResponse == 200
      xList := hb_jsonDecode(cBody)
      IF ValType(xList) == "H" .AND. HHasKey(xList,"data")
         xList := xList["data"]
      ENDIF
      IF ValType(xList) == "A" .AND. Len(xList) > 0
         RETURN .T.                          //es gibt schon einen Kontakt
      ENDIF
   ELSEIF nResponse != 404
      Tr_MsgBox({"Kontakte konnten nicht gelesen werden.","HTTP "+LTrim(Str(nResponse))+" "+cResponse},"HINWEIS")
      RETURN .F.
   ENDIF

   hContact := GetAccountsContact(ku->Nummer)
   IF hContact == NIL
      hContact := GetInvoiceContact(ku->Nummer)
   ENDIF
   IF hContact == NIL .OR. Empty(hContact["email"])
      Tr_MsgBox({"Tilta braucht einen Ansprechpartner mit E-Mail-Adresse.", ;
                 "Beim Kunden ist kein Buchhaltungs- oder Rechnungskontakt", ;
                 "mit E-Mail hinterlegt. Bitte nachtragen und erneut starten."},"KEIN KONTAKT")
      RETURN .F.
   ENDIF

   cName := AllTrim(hContact["name"])
   nPos  := RAt(" ",cName)

   hNew := {=>}
   hNew["buyer_external_id"] := cBuyer
   IF nPos > 0
      hNew["first_name"] := Left(cName,nPos-1)
      hNew["last_name"]  := SubStr(cName,nPos+1)
   ELSE
      hNew["last_name"]  := cName
   ENDIF
   hNew["email"] := hContact["email"]
   IF hContact["id"] != 0
      hNew["external_id"] := LTrim(Str(hContact["id"]))
   ENDIF

   IF Tr_MsgBox({"Als Ansprechpartner an Tilta melden:",cName+"  <"+Trim(hContact["email"])+">","Jetzt anlegen?"},,{"Nein","Ja"}) != 2
      RETURN .F.
   ENDIF

   TxtBox("Ansprechpartner wird angelegt...")
   cBody := __TiltaCall("contacts","POST",hNew,@nResponse,@cResponse)
   TxtClear()
   IF nResponse < 200 .OR. nResponse >= 300
      Tr_MsgBox({"Ansprechpartner konnte nicht angelegt werden.","HTTP "+LTrim(Str(nResponse))+" "+cResponse,Left(cBody,200)},"FEHLER")
      RETURN .F.
   ENDIF
RETURN .T.

/*  Fazilitaet pruefen und bei Bedarf beantragen. Ohne sie gibt es kein Limit
 *  und damit keine Finanzierung - der Schritt muss also auch nachtraeglich
 *  laufen koennen, wenn der Buyer schon existiert.                         */
STATIC PROCEDURE __TiltaEnsureFacility(cBuyer)
   LOCAL cBody, nResponse := 0, cResponse := ""

   __TiltaCall("buyers/"+cBuyer+"/facility","GET",NIL,@nResponse,@cResponse)

   IF nResponse == 404
      IF Tr_MsgBox({"Fuer diesen Buyer gibt es noch keine Kreditfazilitaet.","Jetzt beantragen?"},,{"Nein","Ja"}) != 2
         RETURN
      ENDIF
      //ohne Ansprechpartner lehnt Tilta die Fazilitaet ab (INSUFFICIENT_BUYER_INFO)
      IF ! __TiltaEnsureContact(cBuyer)
         RETURN
      ENDIF
      TxtBox("Fazilitaet wird beantragt...")
      cBody := __TiltaCall("buyers/"+cBuyer+"/facility","POST",NIL,@nResponse,@cResponse)
      TxtClear()
      IF nResponse < 200 .OR. nResponse >= 300
         Tr_MsgBox({"Die Fazilitaet wurde nicht angelegt.","HTTP "+LTrim(Str(nResponse))+" "+cResponse,Left(cBody,200)},"FEHLER")
         RETURN
      ENDIF
   ELSEIF nResponse != 200
      Tr_MsgBox({"Fazilitaet konnte nicht gelesen werden.","HTTP "+LTrim(Str(nResponse))+" "+cResponse},"HINWEIS")
      RETURN
   ENDIF

   __TiltaShowFacility(cBuyer)
RETURN

/*  Stand der Fazilitaet anzeigen. Status: ACTIVE, PENDING, FROZEN, EXPIRED -
 *  frisch beantragt ist sie ueblicherweise PENDING, dann gibt es noch kein
 *  Limit (der Hook get_customercreditlimit wertet das genauso).            */
STATIC PROCEDURE __TiltaShowFacility(cBuyer)
   LOCAL cBody, nResponse := 0, cResponse := ""
   LOCAL hFac

   cBody := __TiltaCall("buyers/"+cBuyer+"/facility","GET",NIL,@nResponse,@cResponse)
   IF nResponse != 200
      Tr_MsgBox({"Fazilitaet konnte nicht gelesen werden.","HTTP "+LTrim(Str(nResponse))+" "+cResponse},"HINWEIS")
      RETURN
   ENDIF

   hFac := hb_jsonDecode(cBody)
   IF ValType(hFac) != "H"
      Tr_MsgBox("Antwort nicht lesbar: "+Left(cBody,120),"HINWEIS")
      RETURN
   ENDIF

   Tr_MsgBox({"Status   : "+IF(HHasKey(hFac,"status"),hFac["status"],"?"), ;
              "Limit    : "+IF(HHasKey(hFac,"total_amount"),LTrim(Transform(hFac["total_amount"]/100,"@E 999,999.99")),"?"), ;
              "Verfuegbar: "+IF(HHasKey(hFac,"available_amount"),LTrim(Transform(hFac["available_amount"]/100,"@E 999,999.99")),"?")}, ;
             "Fazilitaet "+cBuyer)
RETURN

/*  Rechtsform aus dem Trader-Schluessel auf die Tilta-Werte abbilden:
 *  LIMITED_COMPANY, SOLE_TRADER, PARTNERSHIP, PUBLIC_COMPANY, COOPERATIVE,
 *  GOVERNMENT, OTHER. Unbekanntes wird OTHER - der Dialog zeigt den Wert an,
 *  bevor etwas gesendet wird.                                              */
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

#include "x:\run\tilta_api.prg"
