FUNCTION RUN_Invoice_Storno()
   LOCAL oInvoice
   LOCAL getlist := {}

   Head("Eingangsrechnung stornieren")

   NetUse("engkund","ku")
   NetUse( "engrech" ,"rech")
   NetUse( "artikel" ,"art" )
   NetUse( "rechpos" ,"rpos" )

   IF ! SystemUser():CheckPermission("D","PURCHASEINVOICE")
      RETURN NIL
   ENDIF

   oInvoice := Invoice():New()
   
   @ 01,00 SAY "Lieferant" GET oInvoice:cLiefma PICTURE "@!" VALID FindAd(oInvoice:cLiefma,"L",01,25)
   @ 02,00 SAY "Rech.nr. " GET oInvoice:cRenr PICTURE "@!" VALID ! oInvoice:IsReNrNew() //.AND. oInvoice:lComplete
   READ

   IF LastKey() == 27
      RETURN NIL
   ENDIF
   
   oInvoice:Load()

   
   IF Invoice_UnComplete(oInvoice)

      Alert("Buchungspositionen manuell l”schen")

      engre(oInvoice:cLiefma,oInvoice:cRenr)
   ENDIF

   
RETURN NIL

FUNCTION Invoice_UnComplete(SELF) //CLASS Invoice
   LOCAL nNetPrice
	
   rech->( dbSetOrder( 2 ) )
   IF ! rech->( dbSeek( ::cLiefma + ::cReNr ) ) .OR. ! rech->Booked
      RETURN .F.
   ENDIF

   rpos->( dbSetOrder( 1 ) )
   rpos->( dbSeek( ::cLiefma + ::cReNr ) )

   ku->( dbSetOrder( 1 ) )
   ku->( dbSeek( ::cLiefma + "L" ) )

   // lieferant bewegungskonto
   Bewegung( { "RES", 2, ::dReDate, 0, ku->Nummer, 0, ::__nGrAmount*-1, 0, 0, ::cRenr, 0, 0 } )

   DO WHILE ! rpos->( Eof() ) .AND. rpos->Beleg == ::cReNr .AND. rpos->Liefma == ::__cLiefma

      //this cannot be reset
      /*IF rpos->besnr != 0
         bes->( dbSetOrder( 1 ) )
         bes->( dbSeek( Str( rpos->besnr, 6 ) + Str( rpos->posnr, 3 ) ) )

         bes->( rec_lock( 0 ) )
         bes->rate   := ::nRate
         bes->ekpr   := rpos->ekpr
         bes->pe     := rpos->pe
         bes->pay    := ::nHowPay
         bes->rabatt := rpos->rabatt
         bes->code   := 0
         bes->( dbUnlock() )
      ENDIF*/ 

      IF rpos->Artikelnr > 0 // does this position have a product?
         art->( dbSetOrder( 2 ) )
         art->( dbSeek( Str( rpos->artikelnr, 6 ) ) )

         // artikel bewegungskonto
         /*Bewegung( { "RES", 1, ::dReDate, rpos->Artikelnr, ku->Nummer, ;
            rpos->Pe, rpos->ekpr, rpos->Menge*-1, art->Bestand, ;
            rpos->Beleg, rpos->Besnr, 0 } )*/

         // updated prices if the product is not manufactured
         IF ! ArtIsManufactured( art->Artikelnr )            
            /*nNetPrice := 0
            IF ! Empty( rpos->ekpr )
               nNetPrice := rpos->ekpr - ( rpos->ekpr * rpos->rabatt / 100 )
               nNetPrice := nNetPrice + ( nNetPrice * ::__nDiscount / 100 )
            ENDIF*/

            art->( Rec_Lock( 0 ) )
            art->gelqty    -= rpos->menge
            //art->letzte_ek := rpos->ekpr
            //art->pe        := rpos->pe
            //art->netprice  := nNetPrice
            //art->money     := ::cMoney
            //art->rabatt    := rpos->rabatt
            art->( dbUnlock() )
         ENDIF
      ENDIF

      rpos->( dbSkip( 1 ) )
   ENDDO

   //::Save()

   rech->( dbSetOrder( 2 ) )
   IF rech->( dbSeek( ::cLiefma + ::cReNr ) )
      rech->( Rec_Lock( 0 ) )
      rech->Booked  := .F.
      rech->( dbUnlock() )
   ENDIF

   RETURN .T.