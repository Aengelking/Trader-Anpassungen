PROC RUN_UPD_ARTLIEF_LZ
   LOCAL getlist := {}
   LOCAL cLiefma := Space(8)
   LOCAL hLZ
   LOCAL nR,nLZ,oG

   NetUse("artlief","ali")

   DO WHILE .T.
      hLZ := {=>}

      Head("Lieferzeiten Lieferantenartikel aktualisieren")
      @ 01,00 SAY "Lieferant" GET cLiefma PICTURE "@!" VALID ali->(dbSeek( cLiefma ))
      READ

      IF LastKey() == 27
         RETURN
      ENDIF

      ali->(dbSeek( cLiefma ))
      //collect existing delivery times
      DO WHILE ali->Kunde == cLiefma .AND. ! ali->(EOF())
         IF ! ali->LZ $ hLZ
            hLZ[ali->LZ] := ali->LZ
         ENDIF
         ali->(dbSkip())
      ENDDO

      @ 02,00 SAY "Bisher"
      @ 02,08 SAY "Neu"
      nR := 0
      FOR EACH nLZ IN hLZ
         //Aadd(getList,__GetLZ(nR,nLZ,hLZ))
         @ 03+nR,00 SAY Str(nLZ,2)
         @ 03+nR,08 GET hLZ[nLZ]
         /*oG := Get():new( 02+nR, 00, {|x|
            LOCAL oG := GetActive()
            IF x != NIL
            ENDIF
            RETURN hLZ[oG:Cargo]
         },,"99")  
         oG:Cargo := nLZ*/
         //oG:Display()
         //AAdd(getlist,oG)
         nR++
      NEXT
      READ

      IF LastKey() == 27
         RETURN
      ENDIF

      ali->(dbSeek( cLiefma ))
      //set new delivery dates
      DO WHILE ali->Kunde == cLiefma .AND. ! ali->(EOF())
         IF hLZ[ali->LZ] != ali->LZ
            ? "Update ",ali->Matchcode,ali->LZ     
            ali->(Rec_Lock())
            ali->LZ := hLZ[ali->LZ]
            ali->(dbUnlock())    
         ENDIF
         ali->(dbSkip())
      ENDDO


      //Sinkey(0)
   ENDDO

   FUNCTION __GetLZ(nR,nLZ,hLZ)
      LOCAL getlist := {}
      @ 02+nR,00 SAY Str(nLZ,2) GET hLZ[nLZ]
   RETURN Atail(getlist)

