NetUse("engauf","auf")
auf->(dbSetOrder(2))

NetUse("engkund","ku")
ku->(dbSetOrder( 1 ))

auf->(dbSeek( Pad("FP",8)+Str(0,1) ))
ku->(dbSeek( Pad("FP",8)+"K" ))
CLS

DO WHILE Trim(auf->Kundma) == "FP" .AND. auf->Bestat < 3
   IF Right(Str(auf->DTerm,4),2) != "99"
      cLieferTag := GetJITLiefertag(auf->BDatum,ku->Jit_LZ)
      nKW := Val( CalWeek( cLieferTag )) -1
      IF nKW != auf->Dterm
         ? auf->Abnr,auf->Itmnr,cLiefertag,nKw,auf->Dterm
      ENDIF
   ENDIF
   auf->(dbSkip())
ENDDO

Inkey(0,128)