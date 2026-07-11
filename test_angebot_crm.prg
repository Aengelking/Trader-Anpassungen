#include 'inkey.ch'
#include 'set.ch'

/**
Testwerkzeug f�r die CRM-Angebotsanbindung.

Aufruf �ber den Interpreter / MBaseRun:
   MBaseRun(Path("run\test_angebot_crm.prg"))

Man gibt eine Angebotsnummer ein und w�hlt, welchen Hook man simulieren
m�chte:
   - before_print  -> CRM_QuoteAssign  (Angebot einer Opportunity zuordnen /
                      Opportunity-Picker �ffnen)
   - after_print   -> CRM_QuoteReport  (Text-Aktivit�t an die zugeordnete
                      Opportunity melden)

Beide Aufrufe laufen exakt wie in den Hooks �ber LoadPrg + HB_ExecFromArray,
so dass run\crm_email.prg direkt getestet werden kann � ohne echten Druck.
**/

PROC TEST_ANGEBOT_CRM()
	LOCAL nAngnr := 0
	LOCAL nChoice
	LOCAL getlist := {}

	NetUse("angebot","ang")
	NetUse("engkund","ku")
	ang->(dbSetOrder(1))
	ku->(dbSetOrder(1))

	Head("CRM Angebot-Test (before/after print)")

	@ 02,00 SAY "Angebot-Nr." GET nAngnr PICTURE "999999" ;
		VALID (nAngnr > 0 .AND. ang->(dbSeek(Str(nAngnr,6))))
	READ

	IF LastKey() == 27 .OR. Empty(nAngnr)
		RETURN
	ENDIF

	// Angebot + Kunde positionieren (wie im Druckprozess)
	IF ! ang->(dbSeek(Str(nAngnr,6)))
		Wapi_MessageBox(,"Angebot "+LTrim(Str(nAngnr))+" nicht gefunden.","Test",0)
		RETURN
	ENDIF
	ku->(dbSeek(ang->Kundma))

	nChoice := Alert("Welchen Hook f�r Angebot "+LTrim(Str(nAngnr))+" testen?",;
		{"before_print (Zuordnung)","after_print (Aktivit�t)","Abbruch"})

	DO CASE
	CASE nChoice == 1
		TestBeforePrint(nAngnr)
	CASE nChoice == 2
		TestAfterPrint(nAngnr)
	ENDCASE

RETURN

//---------------------------------------------------------------------------
// Simuliert before_print_angebot: CRM_QuoteAssign(nAngnr, ku->Kunde)
//---------------------------------------------------------------------------
STATIC FUNCTION TestBeforePrint(nAngnr)
	LOCAL xRet

	LoadPrg(Path("run\crm_email.prg"))
	xRet := HB_ExecFromArray({"CRM_QuoteAssign", nAngnr, ku->Kunde, ku->Name1})

	IF ValType(xRet) == "L" .AND. xRet
		Wapi_MessageBox(,"before_print OK:" + Chr(13)+Chr(10) + ;
			"Angebot " + LTrim(Str(nAngnr)) + " ist einer Opportunity zugeordnet.","Test",0)
	ELSE
		Wapi_MessageBox(,"before_print: keine Zuordnung (abgebrochen oder Fehler).","Test",0)
	ENDIF

RETURN xRet

//---------------------------------------------------------------------------
// Simuliert after_print_changed_quote: baut denselben Info-Text wie der Hook
// und ruft CRM_QuoteReport(nAngnr, nValue, cText).
//---------------------------------------------------------------------------
STATIC FUNCTION TestAfterPrint(nAngnr)
	LOCAL aValues, aContact, cText, xRet
	LOCAL nValue := 0

	BEGIN SEQUENCE
		aValues := EnquiryAddUp(nAngnr,.T.)
		IF ValType(aValues) == "A" .AND. Len(aValues) >= 2
			nValue := aValues[2]
		ENDIF
	RECOVER
		nValue := 0
	END SEQUENCE

	cText := "Angebot: " + LTrim(Str(nAngnr)) + Chr(13)+Chr(10)
	cText += "Kunde: " + Trim(ku->Name1) + Chr(13)+Chr(10)

	BEGIN SEQUENCE
		aContact := GetContact(ang->Person)
		cText += "Ansprechpartner: " + aContact["name"] + Chr(13)+Chr(10)
		cText += "Telefon: " + aContact["fullphone"] + Chr(13)+Chr(10)
	RECOVER
		//kein Ansprechpartner ermittelbar - nicht fatal f�r den Test
	END SEQUENCE

	cText += "Wert: " + LTrim(Str(nValue,12,2)) + Chr(13)+Chr(10)
	cText += "Gedruckt am: " + DToC(Date()) + " (TEST)"

	LoadPrg(Path("run\crm_email.prg"))
	xRet := HB_ExecFromArray({"CRM_QuoteReport", nAngnr, nValue, cText})

	IF ValType(xRet) == "L" .AND. xRet
		Wapi_MessageBox(,"after_print OK:" + Chr(13)+Chr(10) + ;
			"Aktivit�t an die Opportunity gemeldet.","Test",0)
	ELSE
		Wapi_MessageBox(,"after_print: Meldung fehlgeschlagen." + Chr(13)+Chr(10) + ;
			"Ist das Angebot schon zugeordnet? Ggf. zuerst before_print testen.","Test",0)
	ENDIF

RETURN xRet
