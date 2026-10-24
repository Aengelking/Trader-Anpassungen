PROC RUN_TEST_WA_CALC
    LOCAL oWA := WA():New()
    LOCAL hManuSplit := {=>}
    oWA:Load(9630)
    oWA:Calculate(,,,hManuSplit)
    Alert(ValToPrg(hManuSplit))
RETURN