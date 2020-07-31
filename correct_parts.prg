PROC RUN_CORRECT_PARTS
   LOCAL nPart,lDel
   NetUse("parts","part")
   NetUse("artikel","art")
   art->(dbSetOrder( 2 ))
   part->(dbGoTop())
   CLS
   DO WHILE ! part->(EOF())
      nPart := part->ListArt
      lDel := ! art->(dbSeek( Str(part->Listart,6) ))
      IF lDel
         ? "Deleting "+LTrim(str(part->Listart))
      ENDIF
      DO WHILE nPart == part->ListArt
         IF lDel
            part->(Rec_Lock(0))
            part->(dbDelete())
            part->(dbUnLock())
         ENDIF
         part->(dbSkip())
      ENDDO
      IF Inkey() == 32
         Sinkey(0)
      ENDIF
   ENDDO
   Sinkey(0)
RETURN