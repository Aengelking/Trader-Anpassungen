//
// Quick CleverReach upload test - pushes a single receiver to the DE group
// WITHOUT running the (slow) full contact export.
//
// It sends the same test address with progressively richer payloads and
// reports which step (if any) CleverReach rejects, so the offending field is
// obvious. All REST/OAuth helpers come from the shared cleverreach_api.prg.
//

PROCEDURE RUN_CleverReach_Test
   LOCAL cToken, cGroup, cErr, cEmail, aTests, aTest, lOk, aMsg := {}
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

   // Each step: { label, global_attributes, custom_attributes }
   aTests := {}
   Aadd(aTests,{"1 nur Name", ;
      {"firstname"=>"Test","lastname"=>"Sync"},NIL})
   Aadd(aTests,{"2 + Adresse", ;
      {"salutation"=>"Herr","firstname"=>"Test","lastname"=>"Sync","company"=>"Engelking", ;
       "street"=>"Teststr. 1","zip"=>"53359","city"=>"Rheinbach"},NIL})
   Aadd(aTests,{"3 + state/country", ;
      {"salutation"=>"Herr","firstname"=>"Test","lastname"=>"Sync","company"=>"Engelking", ;
       "street"=>"Teststr. 1","zip"=>"53359","city"=>"Rheinbach","state"=>"NRW","country"=>"DE"},NIL})
   Aadd(aTests,{"4 + Attribute", ;
      {"salutation"=>"Herr","firstname"=>"Test","lastname"=>"Sync","company"=>"Engelking", ;
       "street"=>"Teststr. 1","zip"=>"53359","city"=>"Rheinbach","state"=>"NRW","country"=>"DE"}, ;
      {"umsatz"=>"1234","branche"=>"Test"}})

   Aadd(aMsg,"Gruppe DE = " + cGroup + "   Email = " + cEmail)
   Aadd(aMsg,"")
   FOR EACH aTest IN aTests
      cErr := ""
      lOk := CleverReachUpsert(cToken,cGroup,{CleverReachReceiver(cEmail,aTest[2],aTest[3],.T.)},@cErr)
      Aadd(aMsg,Pad(aTest[1],20) + IF(lOk,"OK","FEHLER: " + cErr))
      IF ! lOk
         EXIT   // stop at the first failing step
      ENDIF
   NEXT

   Tr_MsgBox(aMsg,"CleverReach Test")

RETURN

#include 'x:\run\cleverreach_api.prg'
