FUNC HOOK_GET_FREIGABE_FIELDS(cState)
   
   IF cState == "VMU"
      RETURN {"user","ignore"}
   ELSEIf cState $ {"UNT","ZNG"}
      Return {"user"}
   ELSEIF cState == "MUS"
      RETURN {"user","ignore","forcesonderonignore"}
   Elseif cState == "UNTK"
      RETURN {"customer","canchangesupplier"}
   Elseif cState == "KU"
      RETURN {"customer"}
   Endif

Return {"user","customer"}