/*
 * pack_extern  -  Eine fremde Zeile der Packzettel-Liste bearbeiten.
 *
 * Gerufen von AListRech (tr_148), wenn jemand eine Zeile auswaehlt, die weder
 * Rechnung noch Entnahme ist. Was dann zu tun ist, weiss nur derjenige, der
 * die Zeile beigesteuert hat - deshalb steht es nicht im Kern.
 *
 * Bei den Etiketten aus dem NexusCRM heisst es: PDF holen, drucken, und nach
 * Bestaetigung den Versand zurueckmelden (run\crm_packlist).
 */
FUNCTION HOOK_PACK_EXTERN( hRow )
   IF ValType(hRow) == "H" .AND. HB_HHasKey(hRow, "crm")
      MBaseRun( Path("run\crm_packlist"), {"PACK", hRow} )
   ENDIF
RETURN NIL
