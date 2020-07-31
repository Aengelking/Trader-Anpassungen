NetUse("englsre","re")
NetUse("engkund","ku")

re->(dbSetOrder( 5 ))

re->(dbSetFilter({|| re->Rechdat > StoD("20150101") .AND. re->Taxcode == 3},'rechdat > StoD("20150101") .AND. taxcode == 3')) //rechnung ab 1.1.16 und mit Steuerschlüssel EG
re->(dbSeek( Str(0,3)+"T" ))

CLS

DO WHILE re->Reposnr == 0 .AND. re->Packed
   GotoRechAddress(.T.) //goto the delivery address
   IF ku->CountryIso == "DE" //shipped to address in Germany and is tax-free
      ? re->Rechnr
   ENDIF
   re->(dbSkip())
ENDDO

? "done. Press any key..."
Sinkey(0,128)