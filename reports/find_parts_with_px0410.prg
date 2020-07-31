Head("Artikel mit PX041x")
NetUse("artikel","art",.F.,0)
art->(dbSetOrder( 1 ))

NetUse("parts","part",.F.,0)
part->(dbSetOrder(2))

art->(dbSeek( "PX0410" ))
CLS

cList := ""

Do While Left(art->Matchcode,6) $ "PX0410 PX0411 PX0412 PX0413"
	part->(dbSeek( Str(art->Artikelnr,6), .T. ))
	Do While art->Artikelnr == part->partart
		nRec := art->(Recno())
		art->(dbSetOrder( 2 ))
		art->(dbSeek( Str(part->Listart,6) ))
		? art->Matchcode
		cList += art->Matchcode+Chr(13)+Chr(10)
		art->(dbGoto( nRec ))
		art->(dbSetOrder( 1 ))
		part->(dbSkip())
	Enddo
	art->(dbSkip())
Enddo
gtSetClipboard( cList )
? "Liste wurde in den Zwischenspeicher kopiert."
SInkey(0)