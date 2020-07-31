PARAMETERS nAngnr

LOCAL lChanged := .F.

/*ang->(dbSetOrder( 1 ))
ang->(dbSeek( Str(nAngnr,6) ))
DO WHILE ang->Angnr == nAngNr
  IF ang->bestat == 0
     lChanged := .T.
  ENDIF
  ang->(dbSkip())
ENDDO
IF lChanged
//   Tr_MsgBox("Angebot muss noch genehmigt werden.")
//   RETURN .F.
ENDIF
*/

RETURN .T.