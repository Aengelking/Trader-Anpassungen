FUNCTION HOOK_BEFORE_CREATE_AUFPOS(oAufPos,oContract)
   LOCAL cFilter

   IF oContract != NIL //Abruf aus Rahmen, PrÅfen ob noch ein alter Rahmen besteht der zuerst abgerufen werden soll
      cFilter := 'Right(Str(dterm,4),2)=="99" .AND. bestat <= 2 .AND. vkqty != 0 .AND. besda < StoD("'+DtoS(oContract:Besda)+'")' //offener Ñlterer rahmen
      auf->(dbSetFilter({|| auf->(&(cFilter)) },cFilter))
      auf->(dbSetOrder(6))
      IF auf->(dbSeek( oAufPos:Auftrag:Kundma+oContract:Matchcode ))
         Tr_MsgBox("Bitte zuerst alten Rahmen (AB "+LTrim(Str(auf->Abnr))+") abschlie·en.")
         auf->(dbClearFilter())
         RETURN .F.
      ENDIF
      auf->(dbClearFilter())
   ENDIF
RETURN .T.