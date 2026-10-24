If Tr_MsgBox(t("Alle Tabellen zurücksetzen?"),,{"Nein","Ja"}) != 2
   RETURN
ENDIF
NetUse("option","op")
NetUse("opttab","opt",.T.)
NetUse("optbas","opb",.T.)
opt->(__dbZap())
opb->(__dbZap())

op->(dbGoTop())
DO WHILE ! op->(EOF())
   IF op->Table != 0 .AND. ! opt->(dbSeek( op->Model+Str(op->Table) ))  //skip all existing entries
      opt->(Add_Rec())
      opt->Model    := op->Model
      opt->Table    := op->Table
      opt->Length   := op->Length
      opt->Funktion := op->Funktion
   ELSEIF op->Table == 0 .AND. ! opb->(dbSeek( op->Model ))
      opb->(Add_rec())
      opb->Model  := op->Model
      opb->Model1 := op->Model1
      opb->Matchcode := op->Matchcode
      opb->Price     := op->Price
      opb->Pricex    := op->Pricex
      opb->Artikelnr := op->Artikelnr
   ENDIF
   op->(dbSkip())
ENDDO
