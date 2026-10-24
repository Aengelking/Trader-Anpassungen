#include '\\bull\data\harbour\trader\source\include\david.ch'

//SETTINGS

cArchive := "Benutzer/Amos Engelking/Ausgang"
nLast    := 5  //check last X days

//END OF SETTINGS

oAcc := DV_GetMailAccount()
oArch := oAcc:GetArchive(cArchive)
//oSave := oAcc:GetArchive(cSave)


Head(t("Email versand überprüfen"))

@ 10,10 SAY "Importieren"

nI := 0
DO WHILE nI < oArch:MailItems:Count  .AND. SToD(Left(TtoS(oArch:MailItems[nI]:StatusTime),8)) >= Date()-5
   //IF AT("Weihnachtsfeier",oArch:MailItems[nI]:Subject) == 1
//      ? oArch:MailItems[nI]:Subject
      cText := oArch:MailItems[nI]:BodyText:PlainText
//      dDate := IF(oArch:MailItems[nI]:Error==0,oArch:MailItems[nI]:SendTime,oArch:MailItems[nI]:StatusTime)
      dDate := oArch:MailItems[nI]:StatusTime
      ? StoD(Left(TToS(dDate),8)),oArch:MailItems[nI]:Subject,oArch:MailItems[nI]:Error
//      oItm := oArch:GetArchiveEntryById(oArch:MailItems[nI]:_ID)
//      oItm:Move(oSave)
   //ENDIF
   nI++
ENDDO
@ 10,22 SAY "abgeschlossen"

Inkey(0,128)