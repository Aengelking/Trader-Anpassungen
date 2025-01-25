PROC Change_Drawing()
   LOCAL cMatch := Space( 25 )
   LOCAL getlist := {}
   LOCAL oArt

   IF ! SystemUser():CheckPermission("U","ART_DRAWING")
      RETURN
   ENDIF

   Head( "Zeichnung Ñndern" )

   NetUse("artikel","art")
   NetUse("engabg","abg")

   @ 01,00 SAY "Artikel: " GET cMatch VALID ValidVar( cMatch, 01, 00, 0, "", 0, .T. ) .AND. ! Empty(art->Zeichnung)
   ATail(getlist):Reader := {|oGet,oGetlist, oMenu, oGetMsg| SwapReader(oGet,oGetList,oMenu,oGetMsg) }
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   oArt := Artikel():New(.F.)
   
   @ 02,00 SAY "Zeichnungsnummer" GET oArt:Zeichnung
   @ 03,00 SAY "Revision        " GET oArt:ZeichIndex
   READ

   IF LastKey() == 27
      RETURN
   ENDIF

   IF oArt:Updated()      
      Bewegung({'STD',0,Date(),oArt:Artikelnr,0,oArt:PE,oArt:Letzte_EK,oArt:Bestand,oArt:Bestand,"ZEICHNUNG",0,SystemUser():ID,,,Pad(Trim(oArt:GetField("Zeichnung",.T.))+" "+Trim(oArt:GetField("ZeichIndex",.T.)),25)})
      oArt:Save()         
   ENDIF

   Tr_MsgBox("AuftrÑge mit dieser Zeichnung werden nicht automatisch geÑndert. Bitte prÅfe die AuftrÑge und Ñndere die Zeichnung gegebenenfalls manuell.", "Hinweis", {"OK"})