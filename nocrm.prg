FUNCTION NOCRM_Test()
   LOCAL aList := {},aData,hJson
   LOCAL oNoCrm := RestApi():New("https://engelking.nocrm.io/api/v2/","ff10f687005e643fc6a53f01cd06a646a5440986af412916")
   IF oNoCrm:GetPing() == NIL
      TR_MsgBox("Connection to nocrm.io failed")
      RETURN NIL
   ENDIF
   TxtBox("Leadnamen werden eingelesen")
   aData := oNoCrm:GetLeads({"status"=>{"todo","standby"},"limit"=>1})
   TxtClear()
   IF aData == NIL
      Alert("Fehler: "+oNoCrm:cErrorText)
   ELSE
      FOR EACH hJson IN aData
         Aadd(aList,hb_utf8tostr(hJson["title"]))
      NEXT
      AMenu(aList)
   ENDIF
RETURN NIL

