PARAMETERS nKunde,lMin

IF ValType(lMin) != "L"
   lMin := .F.
ENDIF

IF ku->CountryIso == "DE"
   RETURN IF(lMin,1,3)
ELSEIF ku->CountryIso $ "AT CH FR"
   RETURN IF(lMin,2,4)
ELSE
   RETURN IF(lMin,3,5)
ENDIF
