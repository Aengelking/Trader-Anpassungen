LOCAL hKunden := {=>},aKunden := {}

NetUse("engkund","ku")
NetUse("englsre","re")

re->(dbSetOrder( 8 ))
re->(dbSeek( Str(1,3) ))
re->(dbSkip( -1 ))

DO WHILE ! re->(BOF()) .AND. re->Reposnr ==  0 .AND. re->Rechdat >= Date()-365
   ku->(dbSeek( re->Kunde+"K" ))
   IF ku->Re_Via != "EMAI" .AND. ku->CountryIso == "DE"
      IF ! HHasKey(hKunden,re->Kunde)
         hKunden[re->Kunde] := 0
      ENDIF
      hKunden[re->Kunde]++
   ENDIF
   re->(dbSkip( -1 ))
ENDDO
FOR nX := 1 TO Len(hKunden)
   IF HGetValueAt(hKunden,nX) > 1
      Aadd(aKunden,hGetKeyAt(hKunden,nX))
   ENDIF
NEXT
? "Anzahl: ",Len(aKunden)

cFile := Path("export\kunden_post_rechnung.csv")
SET PRINTER TO (cFile)
SET PRINTER ON

?? "Sprache"+Chr(59)+"Matchcode"+Chr(59)+"Fax"+Chr(59)+"Firma"+Chr(59)+"Straße"+Chr(59)+"PLZ"+Chr(59)+"Stadt"+Chr(59)+"Land"
FOR nX := 1 TO Len(aKunden)
   IF ! Trim(aKunden[nX]) $ "SELF GEKOA PGPOWER TEST"
      ku->(dbSeek( aKunden[nX]+"K" ))
      ? HB_OemToAnsi(ku->Language+Chr(59)+Trim(ku->Kunde)+Chr(59)+ku->Telefax+Chr(59)+Trim(Trim(ku->Name1)+" "+ku->Name2)+Chr(59)+Trim(ku->Street)+Chr(59)+Trim(ku->Plz)+Chr(59)+Trim(ku->Town)+Chr(59)+Trim(GetCountryname(ku->CountryIso)))
   ENDIF
NEXT

SET PRINTER TO
SET PRINTER OFF
