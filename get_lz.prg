//#include 'trader.ch'
#translate BETWEEN(<var>,<lower>,<upper>) => <var> >= <lower> .AND. <var> <= <upper>

FUNCTION HOOK_GET_LZ(oArt,nLZ)

LOCAL nBegin,nEnd

IF nLZ == 0
   nLZ := 12
ENDIF

IF oArt:Ursprung == "CN" //from china, check for chinese new year
   dCNY := MBaseRun(Trim(Tr_getini(1))+"\run\cny",{Year(Date())})
   nBegin :=  dCNY
   nEnd   :=  dCNY+14
ELSE
   nBegin :=  SToD(Str(Year(Date()),4)+"1224")
   nEnd   :=  SToD(Str(Year(Date())+1,4)+"0101")
ENDIF
IF nBegin != NIL
   IF Between(Date(),nBegin,nEnd) //we are currently between xmas and new year
      nLZ += Int((nEnd-Date())/7)
   ELSEIF Between(Date()+nLZ*7,nBegin,nEnd)
      nLZ += Int((nEnd-nBegin)/7)
   ENDIF

ENDIF

RETURN nLZ