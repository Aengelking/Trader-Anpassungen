//
// Quick CleverReach upload test - pushes a single receiver to the DE group
// WITHOUT running the (slow) full contact export. Use it to verify auth,
// endpoint and payload, and to see the real HTTP error on failure.
//
// All REST/OAuth helpers come from the shared cleverreach_api.prg.
//

PROCEDURE RUN_CleverReach_Test
   LOCAL cToken, cGroup, cErr := "", cEmail, aReceivers, lOk
   LOCAL cDefault := "amos.engelking@engelking.de"

   Head("CleverReach Test-Sync")

   cToken := CR_EnsureToken()
   IF Empty(cToken)
      Tr_MsgBox("Keine Verbindung zu CleverReach")
      RETURN
   ENDIF

   cGroup := CleverReachFindGroupId(cToken,"Engelking Kundenstamm DE")
   IF Empty(cGroup)
      Tr_MsgBox("Gruppe 'Engelking Kundenstamm DE' nicht gefunden")
      RETURN
   ENDIF

   IF ! Empty(SystemUser():Email)
      cDefault := Trim(SystemUser():Email)
   ENDIF
   cEmail := Trim(GetBox(Pad(cDefault,50),"Test-Empfaenger (Email)","@S50"))
   IF LastKey() == 27 .OR. Empty(cEmail)
      RETURN
   ENDIF
   IF ! CR_ValidEmail(cEmail)
      Tr_MsgBox("Keine gueltige Email - abgebrochen")
      RETURN
   ENDIF

   // Minimal but representative receiver: email + two standard global fields.
   // (No custom attributes here, so a failure points at endpoint/auth/format
   //  rather than an attribute-name mismatch.)
   aReceivers := {CleverReachReceiver(cEmail, ;
      {"firstname"=>"Test","lastname"=>"Trader-Sync"},NIL,.T.)}

   lOk := CleverReachUpsert(cToken,cGroup,aReceivers,@cErr)
   IF lOk
      Tr_MsgBox("OK - Test-Empfaenger in Gruppe DE gesendet: "+cEmail,"CleverReach")
   ELSE
      Tr_MsgBox(cErr,"CleverReach Fehler")
   ENDIF

RETURN

#include 'x:\run\cleverreach_api.prg'
