/*
 * packlist_rows  -  Fremde Vorgaenge in die Packzettel-Liste stellen.
 *
 * Gerufen von AListRech (tr_148), jedes Mal wenn die Liste neu aufgebaut wird.
 * Das Array traegt die Zeilen aus Rechnungen und Entnahmen; wer hier anhaengt,
 * stellt sich mit dazu.
 *
 * Heute kommt von hier nur eines: die Frankier-Etiketten aus dem NexusCRM. Die
 * gehoeren in dieselbe Liste, weil sie im selben Arbeitsgang gepackt werden -
 * sie sind nur kein Trader-Vorgang und stehen deshalb in keiner Datei, die die
 * Liste sonst liest. Die Arbeit macht run\crm_packlist.
 *
 * Der Aufruf laeuft im Sekundentakt: Was hier lange dauert, laesst die Liste
 * haengen. crm_packlist bricht deshalb ab, statt zu warten, wenn das CRM nicht
 * antwortet.
 */
FUNCTION HOOK_PACKLIST_ROWS( aRecs )
   MBaseRun( Path("run\crm_packlist"), {"ROWS", aRecs} )
RETURN NIL
