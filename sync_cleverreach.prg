//
// CleverReach connection setup & verification.
//
// This entry point authorizes against CleverReach (OAuth) and lists the
// receiver groups so the two "Engelking Kundenstamm DE/EN" group ids can be
// confirmed. The actual address sync (receiver upsert / deactivate) runs from
// the CleverReach export - see RUN_Export_Contacts_Cleverreach.
//
// All OAuth / token / REST helpers live in the shared cleverreach_api.prg.
//

PROC RUN_CleverReach_Sync()
   LOCAL cToken, aGroups, hG, nDE, nEN
   LOCAL aMsg := {}

   Head("CleverReach Verbindung")

   cToken := CR_EnsureToken()
   IF Empty(cToken)
      Tr_MsgBox("Keine Verbindung zu CleverReach (Autorisierung fehlgeschlagen)")
      RETURN
   ENDIF

   aGroups := CleverReachGroups(cToken)
   IF Empty(aGroups)
      Tr_MsgBox("Verbunden, aber keine Empfaengergruppen gefunden")
      RETURN
   ENDIF

   Aadd(aMsg,"Verbindung OK. Empfaengergruppen:")
   Aadd(aMsg,"")
   FOR EACH hG IN aGroups
      IF ValType(hG) == "H"
         Aadd(aMsg,Pad(LTrim(Str(hb_HGetDef(hG,"id",0))),10) + hb_utf8tostr(hb_HGetDef(hG,"name","")))
      ENDIF
   NEXT

   nDE := CleverReachFindGroupId(cToken,"Engelking Kundenstamm DE")
   nEN := CleverReachFindGroupId(cToken,"Engelking Kundenstamm EN")
   Aadd(aMsg,"")
   Aadd(aMsg,"DE-Gruppe: " + IF(nDE > 0,LTrim(Str(nDE)),"NICHT gefunden"))
   Aadd(aMsg,"EN-Gruppe: " + IF(nEN > 0,LTrim(Str(nEN)),"NICHT gefunden"))

   Tr_MsgBox(aMsg,"CleverReach")

RETURN

#include 'x:\run\cleverreach_api.prg'
