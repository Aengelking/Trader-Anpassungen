FUNCTION Approve_MUS( nNummer )

LOCAL nTotAvg := 0
LOCAL lHoliday :=  Date() >= GetValue("HOLIDAY-AMOS-START") .AND. Date() <= GetValue("HOLIDAY-AMOS-END")
LOCAL oMuster := M_Muster():New(.F.)
LOCAL oArt
oMuster:Load(nNummer)

IF AT("CONRAD",Upper(oMuster:Beleg)) == 1
   RETURN {"",{Tr_Getini(28)}}   
ENDIF

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
   RETURN {"Warenwert zu hoch (EUR "+LTrim(Str(nTotAvg,12,2))+")",{IF(lHoliday,33,9)}}
ENDIF


RETURN {"",{Tr_Getini(28)}}