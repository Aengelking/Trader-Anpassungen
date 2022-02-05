PROC RUN_CHECK_ISO
   LOCAL aSupplier := GetIdsWithExtraField("KU","QISO9001")
   LOCAL nLief,oExtra
   LOCAL nWarnDays := 14
   LOCAL aTo := {{"amos.engelking@engelking.de","Amos"},{"daniel.becker@engelking.de","Daniel"}}

   CLS

   NetUse("engkund","ku")

   ku->(dbSetOrder( 8 ))

   aSupplier := GetIdsWithExtraField("KU","QISO9001")

   FOR EACH nLief IN aSupplier
      ku->(dbSeek( Str(nLief) ))
      IF ku->Group != "L"
         ? nLief,"Not a supplier"
      ELSE
         oExtra := ku->(ExtraData():New(nLief))
         ? nLief,oExtra:QISO9001
         IF oExtra:QISO9001+nWarnDays <= Date()
            SendMail(aTo,Trim(ku->Kunde)+" ISO 9001 Zertifikat "+IF(oExtra:QISO9001<Date(),"abgelaufen","l„uft ab"),"Das ISO Zertifikat "+IF(oExtra:QISO9001<Date(),"ist","l„uft")+" am "+DtoC(oExtra:QISO9001)+" ab"+IF(oExtra:QISO9001<Date(),"gelaufen",""))
         ENDIF
      ENDIF
   NEXT

   aSupplier := GetIdsWithExtraField("KU","QISO9001")

   FOR EACH nLief IN aSupplier
      ku->(dbSeek( Str(nLief) ))
      IF ku->Group != "L"
         ? nLief,"Not a supplier"
      ELSE
         oExtra := ku->(ExtraData():New(nLief))
         ? nLief,oExtra:Level,oExtra:QISO9001
         IF oExtra:Level >= 8 .AND. Empty(oExtra:QISO9001)
            SendMail(aTo,Trim(ku->Kunde)+" Hat kein ISO 9001 Zertifikat")
         ENDIF
      ENDIF
   NEXT

   ? "complete"
   //Sinkey(0)
   