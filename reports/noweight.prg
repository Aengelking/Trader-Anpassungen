LOCAL hArt,aArts

Head("Artikel ohne Gewichte")

NetUse("artikel","art")
NetUse("lager","lag")

art->(dbGoTop())

aArts := {}

DO WHILE ! art->(EOF())
   IF art->Manufactur != 8 /*((art->Manufactur == 1 .AND. art->Gruppe == "STWP") .OR. art->Manufactur == 11)*/ .AND. art->Gewicht == 0 .AND. art->Bestand != 0
      lag->(dbSeek( art->Artikelnr ))
      Aadd(aArts,{"MATCH"=>art->Matchcode,"ORT"=>lag->Lagerort})
   ENDIF
   art->(dbSkip())
ENDDO

ASort(aArts,,,{|x,y| x:Ort < y:Ort })

StartPrint(,,"PDF")
oPrinter := GetCurrentPrinterObject()
oPdf     := oPrinter:Data

oPdf:NewPage()



FOR EACH hArt IN aArts
      oPdf:AtSay(hArt:Match)
      oPdf:AtSAy(hArt:Ort,,50)
      oPdf:NewLine()
NEXT


CopyPrint()