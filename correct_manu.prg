#define BULGIN   1
#define CHINA    5
#define SCOLMORE 9
#define TECHNO   11
#define ARCO     10
#define SONSTIGER 8
#define ENGELKING 6

Head("Hersteller korrigieren")

NetUse("artikel","art")

art->(dbSetOrder( 1 ))
//art->(dbSeek( "NZ" ,.T. ))

CLS

nCount := 0
aExclude := {7412,3686,3720,12707,8325,5073,5687,5710,6562}

DO WHILE ! art->(EOF()) //AT("NZ",art->Matchcode) == 1
   nManu := art->Manufactur
   IF AT("NZ",art->Matchcode) == 1 .AND. (AT("KLG",art->Matchcode) != 0 .OR. AT("HLG",art->Matchcode) != 0  .OR. AT("KPG",art->Matchcode) != 0)
      nManu := SCOLMORE
   ELSEIF AT("CM",art->Matchcode) == 1 
      nManu := CHINA
   ELSEIF Left(art->Matchcode,3) $ "THA THB"
      nManu := TECHNO
   ELSEIF Left(art->Matchcode,3) $ "ARS ART"
      nManu := ARCO
   ELSEIF Left(art->Matchcode,2) $ "BX PX MP QX"
      nManu := BULGIN
   ELSEIF art->Manufactur == ENGELKING .AND. Left(art->Gruppe,2) == "KO"
      nManu := SONSTIGER
   ENDIF

   IF nManu != art->Manufactur .AND. AScan(aExclude,art->Artikelnr) == 0
      @ 01,00 SAY art->Matchcode
      art->(Rec_Lock())
      art->Manufactur := nManu
      art->(dbUnLock())
      nCount++
   ENDIF
   art->(dbSkip())
ENDDO

Alert(LTrim(Str(nCount))+" Artikel korrigiert")