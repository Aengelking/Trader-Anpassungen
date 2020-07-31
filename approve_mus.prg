FUNCTION Approve_MUS( nNummer )

LOCAL nTotAvg := 0
LOCAL lHoliday := Date()  >= StoD("20200729") .AND. Date() <= StoD("20200814")

mus->(dbSeek( nNummer ))
DO WHILE ! mus->(EOF()) .AND. mus->Nummer == nNummer
   IF mus->FolgeTo == 0
      oArt := Artikel():New(.F.)
      oArt:Load( mus->Artikelnr )
      nTotAvg += oArt:GetAvgBuyPrice(Date())*mus->Menge
   ENDIF
   mus->(dbSkip())
ENDDO

IF nTotAvg > 50
   RETURN {"Warenwert zu hoch (EUR "+LTrim(Str(nTotAvg,12,2))+")",{IF(lHoliday,37,9)}}
ENDIF


RETURN {"",{Tr_Getini(28)}}