LOCAL hTypes  := { ;
   "AB"=>{"PREFIX"=>"AB","NAME"=>"Auftragsbestätigung","DIR"=>HB_AnsiToOem("Auftragsbestätigungen"),"KEEPFOR"=>6},;
   "AUFMAHN"=>{"PREFIX"=>"AUFMAHN","NAME"=>"Mahhnung","DIR"=>HB_AnsiToOem("Auftragsmahnung"),"KEEPFOR"=>6},;
   "AUF"=>{"PREFIX"=>"AUF","NAME"=>"Auftrag","DIR"=>HB_AnsiToOem("Aufträge"),"KEEPFOR"=>6},;
   "ANG"=>{"PREFIX"=>"Angebot_","NAME"=>"Angebot","DIR"=>"Angebote","KEEPFOR"=>6},;
   "ANF"=>{"PREFIX"=>"ANF_","NAME"=>"Anfrage","DIR"=>"Anfragen","KEEPFOR"=>6},;
   "BA"=>{"PREFIX"=>"Belastungsanzeige_","NAME"=>"Belastungsanzeige","DIR"=>"Belastungsanzeigen","KEEPFOR"=>6},;
   "BES"=>{"PREFIX"=>"Bestellung_","NAME"=>"Bestellung","DIR"=>"Bestellungen","KEEPFOR"=>6},;
   "BB"=>{"PREFIX"=>"BB","NAME"=>"Bestellbestätigung","DIR"=>HB_AnsiToOem("Bestellbestätigungen"),"KEEPFOR"=>6},;
   "LS"=>{"PREFIX"=>"LS","NAME"=>"Lieferschein","DIR"=>"Lieferscheine","KEEPFOR"=>6},;
   "RE"=>{"PREFIX"=>"RE","NAME"=>"Rechnung","DIR"=>"Rechnungen","KEEPFOR"=>10},;
   "PI"=>{"PREFIX"=>"PI","NAME"=>"Proformarechnung","DIR"=>"Proformarechnungen","KEEPFOR"=>6},;
   "TA"=>{"PREFIX"=>"TA","NAME"=>"Terminänderung","DIR"=>HB_AnsiToOem("Terminänderungen"),"KEEPFOR"=>6},;
   "NT"=>{"PREFIX"=>"NT","NAME"=>"Notiz","DIR"=>HB_AnsiToOem("Notizen"),"KEEPFOR"=>6},;
   "KA"=>{"PREFIX"=>"KA","NAME"=>"Kreditauskunft","DIR"=>HB_AnsiToOem("Kreditauskünfte"),"KEEPFOR"=>6},;
   "KAM"=>{"PREFIX"=>"KA","NAME"=>"Kreditauskunft maschinenlesbar","DIR"=>HB_AnsiToOem("Kreditauskünfte\XML"),"KEEPFOR"=>6},;
   "INV"=>{"PREFIX"=>"INVENTUR","NAME"=>"Inventurliste","DIR"=>"Inventur","KEEPFOR"=>10},;
   "ER"=>{"PREFIX"=>"ER","NAME"=>"Eingangsrechnung","DIR"=>"Eingangsrechnungen","DIV"=>"Y","NUMLEN"=>9,"KEEPFOR"=>10}}