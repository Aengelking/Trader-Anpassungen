#include 'd:\harbour\trader\source\include\david.ch'

oApp := CreateObject("DVOBJAPILib.DvISEAPI")
oAccount := oApp:Logon("", "", "", "", "", "AUTH")

cID := oAccount:GetSpecialArchive(DvArchivePersonal):ID
CLS
cId := SubStr(cID,Len(oAccount:GetSpecialArchive(DvArchiveUserRoot):ID)+2)
? cID
? oAccount:User:ID
? TR_getini(28)

oArchive := oAccount:GetArchive(oAccount:GetSpecialArchive(DvArchiveUserRoot):ID+"\"+cId+"\$remind$")
? oArchive:DisplayName

/*For nX := 1 To oArchives:Count-1
        ? oArchives:Item(nX):DisplayName
	? oArchives:Item(nX):Account:User:Name
Next*/
Inkey(0,128)