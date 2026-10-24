FUNCTION UPD_NOCRM
   LOCAL aIds,nX
   NetUse("nocrm","nocrm")
   NetUse("angebot","ang")
   aIds := GetIdsWithExtraField("ang","LEADID")

   FOR nX := 1 TO Len(aIds)
      
      oExtra := ang->(ExtraData():New(aIds[nX]))
      ? aIds[nX],oExtra:LeadId
      IF nocrm->(dbSeek( Str(aIds[nX],6) ))
         nocrm->(Rec_Lock())
      ELSE
         nocrm->(Add_Rec())
         nocrm->Angebot := aIds[nX]
      ENDIF
      nocrm->Lead := oExtra:LeadId
      nocrm->(dbUnLock())
   NEXT

   SinKey(0)
