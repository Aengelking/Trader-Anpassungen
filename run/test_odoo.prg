PROC RUN_TEST_ODOO
LOCAL oAdr := Adresse():New()
LOCAL oOdoo
LOCAL cError

//LoadModule("ODOO.HRB")
LoadModules()
oOdoo := OdooApi():New()
oAdr:LoadMatchcode("MERSCHJO","K")

IF ! oOdoo:UpsertPartner(oAdr,,@cError)
	? "Failed to upsert partner:", cError
ENDIF

Sinkey(0)
