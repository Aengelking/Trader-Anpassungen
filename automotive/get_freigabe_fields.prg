FUNC HOOK_GET_FREIGABE_FIELDS(cState)
   
   IF cState $ {"BAGK","KU"}
      RETURN {"customer"}
   ENDIF

Return {"user"}