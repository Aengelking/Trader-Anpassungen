LOCAL cList := ""
LOCAL cFilter

NetUse("engkund","ku")
NetUse("engauf","auf")
NetUse("skontoa","ska")

Head("Vorkasse Debitoren anlegen")

LX_Start()


//build list of payterms and set as filter
DO WHILE ! ska->(EOF())
   IF ska->(IsPrePay(ska->(Recno())-1))
      IF ! Empty(cList)
         cList += ","
      ENDIF
      cList += Ltrim(Str(ska->(Recno())-1))
   ENDIF
   ska->(dbSkip())
ENDDO
cList := "{"+cList+"}"

cFilter := "Skonto $ "+cList
ku->(dbSetFilter({|| &(ku->(cFilter)) },cFilter))

auf->(dbSetFilter({|| auf->Bestat <= 2 },"bestat <= 2"))

auf->(dbSetOrder( 2 ))

ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" , .T. ))

DO WHILE ku->Group == "K" .AND. ! ku->(EOF())
   IF auf->(dbSeek( ku->Kunde ))
      @ 01,00 SAY ku->Kunde+" "+Pad(Trim(ku->Name1)+" "+ku->Name2,70)
      LX_CreateDebtor()
   ENDIF
   ku->(dbSkip())
ENDDO

ku->(dbClearFilter())
auf->(dbClearFilter())

Tr_MsgBox("Abgeschlossen")