LOCAL nWnr := 11653
NetUSe("werkauf","wer")   
NetUse("werks","we")
   NetUse("artikel","art")
   NetUse( "restime", "rst"  )
   NetUse( "jobs",   "job" )
CLS

   wer->(dbSetOrder(1))
   wer->(dbSeek( str(nWnr,6) ))


   art->(dbSetOrder(2))
   art->(dbSeek( Str(wer->Artno,6) ))
   IF art->Gruppe == "SWPM"
      rst->(dbSetOrder( 1 ))
      rst->(dbSeek( "WA "+Str(wer->Aufno) ))   
      DO WHILE rst->Type == "WA " .AND. rst->No == nWnr
         job->(dbSeek( Str(rst->Job,6) ))
         
         IF AT("PRFEN",Upper(job->Name)) > 0
            SendMail({{"amos.engelking","Samuel"}},"SD-Karte fr FA "+LTrim(Str(nWnr))+" vorbereiten")            
            EXIT
         ENDIF
         rst->(dbSkip())
      ENDDO
   ENDIF

   
   Alert("done")