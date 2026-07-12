SetColor( c_five )
art->(dbSetOrder(1))
art->(dbSeek(re->Matchcode))
@ 01,04 CLEAR TO 08,60
@ 01,04 TO 08,60
//DispBox( 04, 41, 23, 41, 1 )
@ 02,05 SAY "Rechnung "+Str(re->rechnr,6)

IF ! Empty(re->Ref)
   @ 02,30 SAY Trim(re->Reftype)+" "+LTrim(Str(re->Ref))+" "+Trim(Str(re->Refpos))
ENDIF

@ 03,05 SAY "Position "+Str(re->reposnr,6)
@ 04,05 SAY "AB-Nr    "+Str(re->abnr,6)

//@ 05,05 SAY "AB-Pos   "+Str(re->abpos,6)
@ 06,05 SAY "Matchcode  "+re->Matchcode
@ 07,05 SAY "Artikel    "+re->Artikel
SInkey(0,128)