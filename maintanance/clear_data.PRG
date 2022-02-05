PROC RUN_MAINTANCE_CLEAR_DATA
   LOCAL aDir,nX
   LOCAL aExclude := {"FUNCTION","COUNTRI2","COMPFORM","KEY"}
   LOCAL cFile
   LOCAL oRole,oUser,aRights,oPerm

   Head("Clear data")

   IF Lower(getConfigValue("leto_server")) != "localhost"
      Tr_MsgBox("This program only works on localhost")
      RETURN
   ENDIF

   IF Tr_MsgBox("This program will remove all data","WARNING!",{"cancel","OK"}) != 2
      RETURN
   ENDIF
   IF Tr_MsgBox("Really remove all data?","Are you sure?",{"No","Yes"}) != 2
      RETURN
   ENDIF

   dbCloseAll()

   aDir := LETO_Directory("*.dbf")
   FOR nX := 1 TO Len(aDir)
      cFile := StrTran(Upper(aDir[nX,1]),".DBF")
      IF ! cFile $ aExclude         
         ? cFile,"clear"
         NetUse(cFile,cFile,.T.,0)
         (cFile)->(__dbZap())
         (cFile)->(dbCloseArea())
      ELSE
         ? cFile,"excluded"
      ENDIF
   NEXT
   ? "Done"

   /************
   BASIC SETUP
   ************/

   //Setup first user and role
   NetUse("buyer","buy")
   buy->(Add_Rec())
   buy->Buyer := "Administrator"
   buy->Aktive := .T.
   buy->(dbUnlock())

   oRole := Role():New(.T.)
   oRole:Name := "Administrator"
   oRole:Save()

   oUser := User():New()
   oUser:Load(1)
   oUser:AddRole(oRole:Id)

   //setup some initial permissions so that other ones can be set
   aRights := {"RIGHTS","RIGHTS_ROLES","RIGHTS_USER"}

   FOR nX := 1 To Len(aRights)

      oPerm := Permission():New(.T.)
      oPerm:Name := aRights[nX]
      oPerm:Save()

      NetUse("roleperms","rope")
      rope->(Add_Rec(0))
      rope->Role := oRole:Id
      rope->Perm := oPerm:ID
      rope->C := .T.
      rope->R := .T.
      rope->U := .T.
      rope->D := .T.
      rope->(dbUnLock())
   NEXT

   //Create a record in engnr, do not need to set any values
   NetUse("engnr")
   nr->(Add_Rec(0))
   nr->(dbUnLock())

   //Create standard currency
   NetUse("currency","cur")
   cur->(Add_Rec(0))
   cur->Code := "E"
   cur->Symbol := "EUR"
   cur->Currency := "Euro"
   cur->Rateek := 1
   cur->Ratevk := 1
   cur->(dbUnLock())

   //Create Standard payment terms (Prepayment)
   NetUse("skontoa","ska")
   ska->(Add_rec(0))
   ska->Ziel1 := -3
   ska->(dbUnLock())

   NetUse("skontob","skb")
   ska->(Add_rec(0))
   ska->Ziel1 := -3
   ska->(dbUnLock())
   



   inkey(0,128)





