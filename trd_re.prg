NetUse("skontoa","ska",.F.,0)
NetUse("post","post",.F.,0)
NetUse("ups","ups")

SetColor( c_five )
art->(dbSetOrder(1))
art->(dbSeek(re->Matchcode))
@ 01,04 CLEAR TO 20,60
@ 01,04 TO 20,60
//DispBox( 04, 41, 23, 41, 1 )
@ 02,05 SAY "Rechnung "+LTrim(Str(re->rechnr,6))

@ 03,05 SAY HB_AnsiToOem("Währung  ")+Currate(re->Money,"X")
@ 04,05 SAY "Gesamt   "+LTrim(Str(re->poswt,11,2))
@ 05,05 SAY "Porto    "+LTrim(Str(re->ofqty,11,2))
@ 06,05 SAY "MwSt     "+LTrim(Str(re->preis,11,2))
@ 07,05 SAY "Bezahlt  "+LTrim(Str(re->aoqty,11,2))
@ 08,05 SAY "Versandt "+If(re->Packed,"Ja","Nein")
ups->(dbSetOrder( 3 ))
IF re->Packed .AND. ups->(dbSeek( Str(re->Rechnr,10) ))
   @ 08,17 SAY "("+Trim(BUY(ups->Person,.T.))+") "+DtoC(ups->Datum)
ENDIF
aCode :=  {"nicht freigegeben","Versandbereit","gedruckt","bezahlt"}
@ 09,05 SAY "Code     "+aCode[re->Code+1] //If(re->Code==3,"bezahlt",If(re->Code==2,"gedruckt","nicht gedruckt"))
@ 10,05 SAY "Status   "+LTrim(Str(re->Status))
@ 11,05 SAY "Lexware  "+t(If(re->transfer,"übertragen","nicht übertragen"))
@ 12,05 SAY "AB-Nr    "+Ltrim(Str(re->abnr,6))
@ 13,05 SAY "Letzter Zahlungseingang "+DToC(re->Paydate)
ska->(dbGoto( re->Skonto+1 ))
Skont(14,05,ska->Ziel1,ska->Ziel2,ska->Ziel3,ska->Rate1,ska->Rate2,ska->Rate3,"D")

@ 15,05 SAY "Versand Rechnung:"
post->(dbSeek( "RE"+Str(re->Rechnr,6) ))
nX := 1
DO WHILE post->Nummer == re->Rechnr .AND. post->Typ == "RE"
   @ 15+nX,05 SAY Left(TtoC(StoT(post->DateTime)),14)
   @ 15+nX,30 SAY IF(post->Via == "EMAI","per Email",IF(post->Via == "INT ","intern",""))
   nX++
   IF nX == 4
      EXIT
   ENDIF
   post->(dbSkip())
ENDDO

SInkey(0,128)