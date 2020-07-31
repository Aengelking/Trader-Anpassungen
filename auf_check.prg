LOCAL nTotal := 0
LOCAL nNeed  := 0

NetUse("auftrag","ab")
ab->(dbGoBottom())
CLS
DO WHILE ! ab->(BOF()) .AND. ab->Besda >= StoD("20140101")
   oAuftrag := Auftrag():New()
   oAuftrag:Load(ab->Abnr)
   //? ab->AbNr
   nTotal++
   IF ! oAuftrag:Erledigt
     cText := Hook("approve_auftrag",{oAuftrag},"OK")
     IF cText != "OK"
        ? ab->Abnr
        //? cText
        nNeed++
     ENDIF
   ENDIF
   ab->(dbSkip(-1))
ENDDO
Alert(HB_AnsiToOem("Anzahl Aufträge: ")+LTrim(Str(nTotal))+";"+HB_AnsiToOem("Genehmigungen:")+LTrim(Str(nNeed)))
//Inkey(0,128)