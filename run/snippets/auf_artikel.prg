FUNC SNIPPET_AUF_ARTIKEL(oPrinter)
   LOCAL oPos := oPrinter:oObject:Positions:GetRecord(auf->ContrPos)
If proforma$"yYjJ" .OR. auf->contrpos==0 .OR. oPos:Matchcode != auf->Matchcode
   IF ART->PRMATCH
      RETURN LEFT(auf->matchcode+SPACE(35),35)
   ELSEIF LEFT(art->matchcode,1) = "@"
      RETURN LEFT(TEXTSHO(auf->text,0,0,"tx",1),35)
   ENDIF
   RETURN LEFT(art->artikel,35)
ENDIF
RETURN ""

//If(proforma$"yYjJ".OR.auf->contrpos==0,IF(ART->PRMATCH,LEFT(auf->matchcode+SPACE(35),35),LEFT(IF(LEFT(art->matchcode,1) = "@",TEXTSHO(auf->text,0,0,"tx",1),art->artikel),35)),"")
