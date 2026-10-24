#include 'inkey.ch'
PROC MASK_TRD_WA
LOCAL nLeft,nRight,nC1,nC2
LOCAL oBrowse
LOCAL cMe
LOCAL nAufno := wer->Aufno
LOCAL lRahmen := Right(Str(wer->Termin,4),2) == "99"
LOCAL lShiped

SetColor( c_five )
nLeft  := 00
nRight := 70

art->(dbSetOrder( 2 ))
art->(dbSeek( Str(wer->Artno,6) ))
cMe := Me(art->Me)

Box( 02, nLeft, 31, nRight,,.T.,2)

@ 03,01 SAY "AUFTRAG:    ["+Str(wer->Aufno,6)+"]"
@ 04,01 SAY "Entnahme:   ["+Str(wer->Lagnum,6)+"]"
IF ! Empty(wer->Liefma)
   @ 05, 01 SAY "Lieferant:  ["+wer->Liefma+"]"
   @ 06, 01 SAY "Bestellung: ["+Str(wer->Besnr,6)+"/"+Ltrim(Str(wer->BesPos))+"]"
ENDIF

@ 03,30 SAY "Artikel:   ["+wer->Matchcode+"]"

IF lRahmen
   wer->(dbSetOrder( 12 ))
   nCalled := wer->(LETO_SUM("qty",".T.",nAufno,nAufno))
   @ 04, 30 SAY "Rahmenme.: ["+Transform(wer->Qty+nCalled,Me(art->Me))+"]"
   @ 05, 30 SAY "Abgerufen: ["+Transform(nCalled,cMe)+"]"
ELSE
   @ 04, 30 SAY "Menge: ["+Transform(wer->Qty,Me(art->Me))+"]"
   @ 05, 30 SAY "Gefertigt: ["+Transform(wer->GelQty,cMe)+"]"
ENDIF



IF lRahmen
   nRahmen := wer->Aufno

   wer->(dbSetOrder( 12 ))
   IF wer->(dbSeek( Str(nAufno,6) ))
      oBrowse := wer->(TBrowseTr():New(20,02,30,38))
      oBrowse:lBox := .F.
      oBrowse:WhileBlock := {|| wer->Frame == nAufno }
   	oBrowse:NewColumn(Pad("FA",6)+" "+PadL("Menge",12)+" "+PadL("Gefertigt",12)+Space(2),{|| Str( wer->Aufno, 6)+" "+PadL(Transform(wer->Qty,cMe),12)+" "+PadL(Transform(wer->GelQty,cMe),12)+Space(2)})
   	oBrowse:AddKey(27,{|| .F. })
   	@ 19,02 SAY t("Einteilungen")
   ENDIF
ELSE
   NetUSe("lagerne","lne")
   lne->(dbSetOrder(1))
   IF wer->Status < 3 .OR. ! lne->(dbSeek(wer->LagNum))
      @ 20,02 SAY "Ware nicht versandt"
   ELSE
      IF lne->Packed  
         lShiped := .T.       
         @ 20,02 SAY "Ware versandt am "+DtoC(lne->Datum)
         @ 20,38 SAY "< Sendung verfolgen >" COLOR c_two
      ELSE
         @ 20,02 SAY "Ware im Versand"
      Endif
   Endif

ENDIF

IF oBrowse != NIL
   oBrowse:EventLoop()
ELSE
   DO WHILE SInkey(0) != 27
      If LastKey() == 13 .AND. lShiped
         Einfug(0,wer->Lagnum,.F.,.F.)
      Endif
   ENDDO
ENDIF
