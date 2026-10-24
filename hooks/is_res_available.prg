PARAMETERS nRes,tStart

IF nRes == 8 //Celina
   IF tStart >= StoT("20180101000000")
      RETURN {.T.,.T.}
   ELSEIF DoW(tStart) == 1 .OR. DoW(tStart) == 5
      RETURN {.F.,.F.}
   ELSE
      RETURN {.T.,.F.}
   ENDIF
ENDIF

RETURN {.T.,.T.}