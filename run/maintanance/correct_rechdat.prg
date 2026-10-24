LOCAL aList := {}
LOCAL dNewDate := StoD("20180331")
NetUse("post","post")
NetUse("englsre","re")
re->(dbSetOrder( 8 ))
re->(dbSeek( Str(0,3)+Str(48108,6) ))

Aadd(aList,{"Rechnung","Datum alt","Datum neu"})
DO WHILE ! re->(EOF()) .AND. re->Reposnr == 0
   IF re->Rechdat <= dNewDate .AND. re->PosWt != 0 .AND. ! post->(dbSeek( "RE"+Str(re->Rechnr,6) ))
      Aadd(aList,{re->Rechnr,re->Rechdat,dNewDate})
      ? re->Rechnr

      oRechnung := Rechnung():New()
      oRechnung:Load(re->Rechnr)
      oRechnung:Rechdat := dNewDate
      oRechnung:Save()

   ENDIF
   re->(dbSkip())
ENDDO

cFile := Trim(Tr_GetINI(1))+"\export\correct_rechdat.csv"
SaveAsCSV(cFile,aList)