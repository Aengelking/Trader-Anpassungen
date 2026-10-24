
NetUse("artikel","art")
NetUse("artkund","aku")


art->(dbSeek( "PA195015BK" ))
aku->(dbSeek( Pad("BACHMANG",8)+Str(art->Artikelnr,6) ))

StickPrint("KUNDENART")
