FUNCTION RUN_SHIP_PRICE_15( nPreis,nGewicht,hPakData )
   LOCAL nRabatt := GetValue("SHIP_UPS_REBATE",0.70,"UPS Rabatt")
   LOCAL nAussenGebiet := GetValue("SHIP_UPS_AUSSEN",0.52,"UPS Auáengebietszuschlag")
   LOCAL nAussenMin := GetValue("SHIP_UPS_AUSSEN_MIN",25.65,"UPS Mindestauáengebietszuschlag")
   LOCAL hPeak := GetValue("SHIP_UPS_PEAK",{"CN"=>1.11,"IN"=>0.22},"UPS Peak Zuschl„ge")

   LOCAL hUPSSurcharge   

   HB_SYMBOL_UNUSED(hPakData)
   
   hUPSSurcharge := HB_JsonDecode(MemoRead(Path("ups_fuel.json"))) //RUN_GET_UPS_FUELSURCHARGE()

   nPreis += nPreis*hUPSSurcharge["NON-EU"]
   nPreis *= 1-nRabatt

   IF ku->CountryIso == "IN"
      nPreis += Max(nGewicht*nAussenGebiet,nAussenMin)*(1+hUPSSurcharge["NON-EU"])
   ENDIF
   IF ku->CountryIso $ hPeak
      nPreis += nGewicht*hPeak[ku->CountryIso]*(1+hUPSSurcharge["NON-EU"])
   ENDIF

RETURN nPreis