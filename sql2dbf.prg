
SqlOpen("contacts","conts")
/*COPY TO (Trim(Tr_Getini(1))+"\contacts.dbf") VIA "DBFCDX"
NetUse("contacts","conts2",.F.,0)
nX := 1
Do While nX <= conts->(OrdCount())
	conts2->(OrdCreate( Trim(Tr_Getini(1))+"\ntx\contacts.cdx" ,"CONTACTS"+StrZero(nX,2),conts->(OrdKey(nX)) ))
	? nX,conts->(OrdKey(nX))
	nX++
Enddo
conts->(dbCloseArea())
Alert("Done")*/