PROC REPORT_LAGERORTE_OHNE_INV
LOCAL dDate := BoY(Date())
LOCAL getlist := {}

Head(t("Lagerorte ohne Inventur"))

IF Tr_Getini(28) != 9
   Tr_MsgBox("Zugang verweigert")
   RETURN
ENDIF

NetUse("artikel","art")
NetUse("lagerort","lago")
NetUse("lager","lag")

@ 01,00 SAY "Letzte Inventur vor" GET dDate VALID dDate < Date()
READ

IF LastKey() == 27
   RETURN
ENDIF

art->(dbSetOrder(2))
lago->(dbSetOrder(2))
lag->(dbSetOrder(2))

lago->(dbSetFilter( {|| lago->Invdate < dDate },"invdate<StoD('"+DtoS(dDate)+"')"))
lago->(dbGoTop())

DO WHILE ! lago->(EOF())
   ? lago->Lagerort
   
   lago->(dbSkip())
ENDDO