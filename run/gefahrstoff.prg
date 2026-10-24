/*
   PROCEDURE: RUN_GEFAHRSTOFF
   DESCRIPTION: This procedure runs the Gefahrstoff program.
*/
#include 'inkey.ch'
PROC RUN_GEFAHRSTOFF
   LOCAL aArt := GetIdsWithExtraField("art","GEFAHR")
   //LOCAL aArt2 := GetIdsWithExtraField("art","SDS")
   LOCAL aList := {},oBrowse
   LOCAL oExtra
	LOCAL nX,nMont,nExt,nBestand
   LOCAL nH255Gewicht := 0
   LOCAL nGewicht,cLager

	NetUse("artikel","art")
   NetUse("lager","lag")
   NetUse("lagerort","lago")
   NetUse("werkauf","wer")
   NetUse("werks","we")

	art->(dbSetOrder( 2 ))
   lag->(dbSetOrder( 1 ))

   Head("Gefahrstoffverzeichnis")
   
   TxtBox("Gefahrstoffe werden eingelesen...")

	FOR nX := 1 TO Len(aArt)
      
		IF art->(dbSeek( Str(aArt[nX],6) )) .AND. ! art->Obsolete
         oExtra := art->(ExtraData():New(art->Artikelnr))
         IF oExtra:Gefahr
            nMont := 0
            nExt := 0
            
            lag->(dbSetOrder(1))
            lag->(dbSeek( art->Artikelnr ))
            cLager := ""
            DO WHILE lag->Artikelnr == art->Artikelnr
               IF Left(lag->Lagerort,4) == "097/"
                  nMont += lag->LagerMenge
               ELSE
                  lago->(dbSeek( lag->Lagerort ))
                  IF lago->Fremd
                     nExt += lag->LagerMenge
                  ELSE
                     IF ! Empty(cLager)
                        cLager += ", "
                     ENDIF
                     cLager += Trim(lag->Lagerort)
                  ENDIF
               ENDIF
               lag->(dbSkip())
            ENDDO
            nBestand := art->Bestand-nMont-nExt
            we->(dbSetOrder( 2 ))
            wer->(dbSetOrder( 9 ))
            wer->(dbSeek( Str(1,1), .T. ))
            DO WHILE wer->Status <= 3 .AND. ! wer->(EOF())
               IF we->(dbSeek(Str(wer->Aufno,6)+Str(art->Artikelnr,6)))
                  nMont += we->BookQty
              ENDIF
               wer->(dbSkip())
            ENDDO
            IF Trim(art->Me) == "kg"                
               nGewicht := 1000
            ELSEIF Trim(art->Me) == "g"
               nGewicht := 1
            ELSE
               nGewicht := oExtra:NettoGew
            ENDIF
            
            hReqInq := GetProductRequirementAndIncoming(art->artikelnr)

            Aadd(aList,{;
               "ARTIKELNR"=>aArt[nX],;
               "BESTAND"=>nBestand,;
               "MONTAGE"=>nMont,;
               "EXTERN"=>nExt,;
               "FILE"=>GetFileName(),;
               "LAGER"=>cLager,;
               "H225"=>oExtra:Gef_H225,;
               "NETTO"=>nGewicht*(art->Bestand-nExt)/1000,;
               "BEDARF"=>hReqInq["avgrequirement"];
            })
            nH255Gewicht += nGewicht*(art->Bestand-nExt)/1000
//            ? aArt[nX],art->artikel,Pad(Transform(art->Bestand-nMont,Me(art->Me)),12),Pad(Transform(nMont,Me(art->Me)),12),art->Me
         ENDIF
      ENDIF
	NEXT
   
   //Alert("Gesamtgewicht H225: "+LTrim(Str(nH255Gewicht))+"kg")

   /*?
   ? "-- NUR SICHERHEITSDATENBLATT (kein Gefahrstoff) --"
   FOR nX := 1 TO Len(aArt2)
      //IF !aArt2[nX] $ aArt
		   IF art->(dbSeek( Str(aArt2[nX],6) )) 
            oExtra := art->(ExtraData():New(art->Artikelnr))
            IF ! oExtra:Gefahr
		         ? aArt2[nX],art->artikel,Transform(art->Bestand,Me(art->Me)),art->Me
            ENDIF
         ENDIF
      //ENDIF
	NEXT*/

   TxtClear()

   @ MaxRow()-9,00 TO MaxRow()-9,MaxCol() 
   @ MaxRow()-8,00 SAY "Gesamtmenge H225: "+Str(nH255Gewicht,6,2)+" kg"

   oBrowse := TABrowse():New(01,00,MaxRow()-10,MaxCol())
   oBrowse:aData := aList
   oBrowse:lBox := .F.

   oBrowse:NewColumn("   "+"Art.nr "+Pad("Produkt",35)+" "+Pad(PadL("Lager",6),12)+" "+Pad("Montage",12)+" "+Space(4)+" "+"Gewicht"+" "+Pad("pro Monat",12),{||
      LOCAL oRow := oBrowse:CurrentDataRow()
      LOCAL hReqInq
      LOCAL cRet := ""
      
      art->(dbSeek( Str(oRow:Artikelnr,6) ))
      

      cRet := IF(Empty(oRow:File),"-"," ")+" "
      cRet += IF(oRow:H225,"!"," ")
      cRet += Str(oRow:Artikelnr)+" "+art->Artikel+" "+Pad(Transform(oRow:Bestand,Me(art->Me)),12)+" "
      cRet += Pad(Transform(oRow:Montage,Me(art->Me)),12)+" "+art->Me+" "
      IF oRow:Netto == 0 .AND. oRow:Bestand > 0
         cRet += Pad("???",6,2)
      ELSE 
         cRet += Str(oRow:Netto,6,2)
      ENDIF
      cRet += " "+Pad(TransForm(oRow:Bedarf,Me(art->Me)),12)+" "+Pad(oRow:Lager,70)
      RETURN cRet
   })

   oBrowse:AddKey(27,{|| .F. })
   oBrowse:AddKey(32,{|| 
      art->(dbSeek( Str(oBrowse:CurrentDataRow():Artikelnr,6) ))
      DispInfo("trd_01")
      RETURN .T.
   })
   oBrowse:AddKey(13,{|| 
      IF ! Empty(oBrowse:CurrentDataRow():File)
         WAPI_ShellExecute(,"open",oBrowse:CurrentDataRow():File)
      ENDIF
      RETURN .T. 
   })
   oBrowse:AddKey(K_F8,{||
      art->(dbSeek( Str(oBrowse:CurrentDataRow():Artikelnr,6) ))
      ArtFo()
      RETURN .T.
   })

   oBrowse:EventLoop()

	//Sinkey(0)
RETURN

STATIC FUNC GetFileName()
   LOCAL cDir := "Y:\Technik\Sicherheitsdatenbl„tter\"
   LOCAL aFiles := Directory(cDir+LTrim(Str(art->Artikelnr))+"_*")
   IF Len(aFiles) > 0
      RETURN cDir+aFiles[1,1]
      //@ ++nR,nC1 SAY "Sicherheitsdatenblatt mit >S< ”ffnen "
   ENDIF
RETURN ""

	