/**
  * Export article data for Mercateo
  *
  * TODO:
  *		- Remove special chars like &
  **/
BMECat("MERCATEO")
If TR_MsgBox("Upload to Mercateo?",,{"No","Yes"}) == 2
	? "Uploading to Mercateo..."
	__run("d: & cd \trader30\export & ftp -i -n -s:..\prg\mercateo_ftp.txt ftp.mercateo.com")
	?? "done"
	? "Press any key to continue"
	Inkey(0,128)
Endif