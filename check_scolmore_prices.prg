nEx := Currate("P","E")
dDate := SToD("20150430")
IF  nEx > 1.48   //.AND. dDate >= Date()
   SendMail({{"amos.engelking@engelking.de","Amos"}},"Pfund-Kurs zu hoch. Bitte Scolmore-Preisliste anpassen","")
ENDIF