NetUse("approval","apr")
NetUse("engauf","auf")
NetUse("angebot","ang")
NetUse("engbes","bes")

apr->(__dbSetFilter({|| apr->ApprovedBy == 0 .AND. SToD(apr->RequestDa) < Date()-2 }))
apr->(dbGoTop())

cText := "Folgende Genehmigungen stehen noch aus:<pre>"
cText += "<br>Typ"+" "+Pad("Nummer",6)+" "+Pad("Datum",8)+" "+"Uhrzeit"

lFound := .F.
DO WHILE ! apr->(EOF())
   lNot := .T.
   IF Trim(apr->Type) == "AUF"
      IF ! auf->(dbSeek( Str(apr->No,6) ))
         lNot := .F.
      ELSEIF auf->Abnr == apr->No .AND. auf->BeStat < 3
         lNot := .F.
      ENDIF
   ELSEIF Trim(apr->Type) == "ANG"
      IF ! ang->(dbSeek( Str(apr->No,6) )) .OR. ang->BeStat == 3
         lNot := .F.
      ENDIF
   ELSEIF Trim(apr->Type) == "BES"
      IF ! bes->(dbSeek( Str(apr->no,6) ))
         lNot := .F.
      ENDIF
   ENDIF
   IF lNot
      lFound := .T.
      cText += "<br>"+apr->Type+" "+Str(apr->no,6)+" "+Left(TtoC(SToT(apr->Requestda)),14)
   ENDIF
   apr->(dbSkip())
ENDDO

ctext += "</pre>"
IF lFound
   SendMail({{"amos.engelking@engelking.de","Amos","CC"},{"thimo.hamma@engelking.de","Thimo"}},HB_AnsiToOem("Auﬂstehende Genehmigungen"),cText,,,,.T.)
ENDIF

//SInkey(0)
