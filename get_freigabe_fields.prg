FUNC HOOK_GET_FREIGABE_FIELDS(cState)

   If cState $ "UNT"
      Return {"user"}
   ELSEIF cState == "MUS"
      RETURN {"user","ignore","forcesonderonignore"}
   Elseif cState $ "UNTK KU"
      RETURN {"customer"}
   Endif

Return {"user","customer"}