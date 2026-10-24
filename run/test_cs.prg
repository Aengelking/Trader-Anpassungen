PROC Test_CS()
   LOCAL oCS
   LOCAL aP := {}

   oCS := CreditSafe()
   Aadd(aP,SOAPParameter():New("countries"))
   ATail(aP):CreateChild("CountryCode","RO",,"http://schemas.datacontract.org/2004/07/Creditsafe.GlobalData")
   
   oXML := oCS:Call("GetPossibleSearchCriteria",aP)

   oName :=  TXmlIteratorScan():New(oXML:oRoot):Find("Name")
   ? oName:toString()
   
   
	//? ValToPrg(oCs:Call("getcountries"),{})
	Sinkey(0)

   #include "x:\run\creditsafe.prg"
