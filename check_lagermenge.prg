NetUse("lager","lag")
NetUse("artikel","art")

CLS

lag->(dbGotop())
art->(dbSetOrder( 2 ))

DO WHILE ! lag->(EOF())
   IF lag->Lagermenge != Int(lag->Lagermenge)
      art->(dbSeek( Str(lag->Artikelnr,6) ))
      IF Trim(art->Me) == "STCK"
         ? art->Matchcode,lag->Lagerort,lag->Lagermenge
      ENDIF
   ENDIF
   lag->(dbSkip())
ENDDO

SInkey(0)