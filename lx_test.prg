If ! LX_Start()
	Alert("No connection")
Else
//	Alert( Str(LX_GetSaldo(7140,Date()),12,2) )

	Alert( Str(LX_GetSaldo(3970,Date()),12,2) )
	Alert( Str(LX_GetSaldo(7050,Date()),12,2) )

Endif