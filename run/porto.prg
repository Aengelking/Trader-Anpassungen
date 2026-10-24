NetUse("englsre","re")
SET FILTER TO (re->Reposnr == 0 .OR. AT("PORTO",re->Matchcode) != 0) .AND. Year(re->Rechdat) == 2014

re->(dbGoTop())

nTotal := 0

DO WHILE ! re->(EOf())
   nPorto := IF(re->Reposnr==0,re->OfQty,re->Poswt)
   ? re->Rechnr,nPorto
   nTotal += nPorto
   re->(dbSkip())
ENDDO

Alert("Gesamt: "+LTrim(Str(nTotal)))