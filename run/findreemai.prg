NetUse("englsre","re")
re->(dbSetOrder( 8 ))
re->(dbSeek( Str(1,3) ))
re->(dbSkip( -1 ))

NetUse("engkund","ku")
nCOunt := 0

DO WHILE ! re->(BOF()) .AND. nCount < 500
   ku->(dbSeek( re->Kunde+"K" ))
   IF ku->Re_Via == "EMAI"
      ? re->Rechnr
      EXIT
   ENDIF
   re->(dbSkip( -1 ))
   nCount++
ENDDO

? "Press key"
Inkey(0,128)