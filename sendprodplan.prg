
cHTML := CompleteProdPlan(2,"WETEC",.F.)
aEmails := {}
Aadd(aEmails,{"amos.engelking@engelking.de","Amos"})
Aadd(aEmails,{"hp.schweiss@engelking.de","HP"})
Aadd(aEmails,{"stojkovski@smart-electronic.de","Hr. Stojkovski"})
//Aadd(aEmails,{"hoefler@smart-electronic.de","Hr. Hoefler"})
SendMail(aEmails,"Produktionsplan WETEC",cHTML,{},.F.,0,.T.)