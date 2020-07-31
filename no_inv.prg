LOCAL cPath := Trim(Tr_getini(1))+"\export\"
LOCAL aDir := Directory(cPath+"inventur*.csv")
LOCAL aRegex

NetUse("inventur","inv")
NetUse("ID","ID")
CLS
FOR nX := 1 TO Len(aDir)
   ? aDir[nX,1]
   aRegex := HB_Regex("inventur_([0-9]{8})_([0-9\-]{8})",aDir[nX,1])
   IF Len(aRegex) == 3
      ? aRegex[2],StoD(aRegex[2])
      ? aRegex[3],StrTran(aRegex[3],"-",":")
      IF inv->(dbSeek( aRegex[2]+Left(StrTran(aRegex[3],"-",":"),4) ,.T. ))
         ? "found ",inv->Date,inv->Time
         IF inv->ID == 0
            NetUse("ID","ID")
            IF ! id->(dbSeek( "INV" ))
               id->(Add_Rec(0))
               id->Alias := "INV"
            ELSE
               id->(Rec_Lock(0))
            ENDIF
            nID   := id->ID+1
            id->ID := nID
            id->(dbUnLock())
            inv->(Rec_Lock())
            inv->ID := nID
            inv->(dbUnLock())
            AddFileToArchive("INV",nID,cPath+aDir[nX,1])
         ENDIF
      ENDIF
   ENDIF
NEXT
Sinkey(0)