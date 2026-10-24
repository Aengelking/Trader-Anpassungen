#include 'inkey.ch'
#include 'set.ch'

/**
Testwerkzeug fï¿½r die CRM-Angebotsanbindung.

Aufruf ï¿½ber den Interpreter / MBaseRun:
   MBaseRun(Path("run\test_angebot_crm.prg"))

Man gibt eine Angebotsnummer ein und wï¿½hlt, welchen Hook man simulieren
mï¿½chte:
   - before_print  -> CRM_QuoteAssign  (Angebot einer Opportunity zuordnen /
                      Opportunity-Picker ï¿½ffnen)
   - after_print   -> CRM_QuoteReport  (Text-Aktivitï¿½t an die zugeordnete
                      Opportunity melden)

Beide Aufrufe laufen exakt wie in den Hooks ï¿½ber LoadPrg + HB_ExecFromArray,
so dass run\crm_email.prg direkt getestet werden kann ï¿½ ohne echten Druck.
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
		Tr_MsgBox("Angebot "+LTrim(Str(nAngnr))+" nicht gefunden.")
		RETURN
	ENDIF
	ku->(dbSeek(ang->Kundma))

	nChoice := Alert("Welchen Hook fr Angebot "+LTrim(Str(nAngnr))+" testen?",;
		{"before_print (Zuordnung)","after_print (Aktivit„t)","Abbruch"})

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
	xRet := HB_ExecFromArray({"CRM_QuoteAssign", nAngnr, LTrim(Str(ku->Nummer)), ku->Name1})

	IF ValType(xRet) == "L" .AND. xRet
		Tr_MsgBox({"before_print OK:" , ;
			"Angebot " + LTrim(Str(nAngnr)) + " ist einer Opportunity zugeordnet."})
	ELSE
		Tr_MsgBox({"before_print: keine Zuordnung (abgebrochen oder Fehler)."})
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
		//kein Ansprechpartner ermittelbar - nicht fatal fï¿½r den Test
	END SEQUENCE

	cText += "Wert: " + LTrim(Str(nValue,12,2)) + Chr(13)+Chr(10)
	cText += "Gedruckt am: " + DToC(Date()) + " (TEST)"

	LoadPrg(Path("run\crm_email.prg"))
	xRet := HB_ExecFromArray({"CRM_QuoteReport", nAngnr, nValue, cText})

	IF ValType(xRet) == "L" .AND. xRet
		Tr_MsgBox({"after_print OK:" , ;
			"Aktivit„t an die Opportunity gemeldet."})
	ELSE
		Tr_MsgBox({"after_print: Meldung fehlgeschlagen." , ;
			"Ist das Angebot schon zugeordnet? Ggf. zuerst before_print testen."})
	ENDIF

RETURN xRet
