#define CRLF Chr(13)+Chr(10)
FUNCTION RUN_Angebote_NoQuote()
   LOCAL hUsers := {=>}, cEmailContent,  dDaysAgo,nDaysAgo := 7
   dDaysAgo := Date() - nDaysAgo


   // Use the database and filter for Angebote
   NetUse("angebot", "ang")
   NetUse("buyer","buy")
   NetUse("artikel","art")

   // Set the filter for ang table
   ang->(dbSetOrder(1))
   ang->(dbSetFilter({|| ang->vkpr == 0 .AND. ang->Besda < dDaysAgo .AND. ang->Bestat < 3}, ;
                     "vkpr == 0 .AND. Besda < StoD('" + DtoS(dDaysAgo) + "') .AND. Bestat < 3"))

   ang->(dbGoTop())

   art->(dbSetOrder(2))

   // Collect the relevant Angebote into a content string

   DO WHILE ! ang->(EOF())
      ? ang->Angnr,ang->Buyer
      IF Left(ang->Matchcode,4) != "TEXT"
         IF ! ang->Buyer $ hUsers
            hUsers[ang->Buyer] := ""
         ENDIF
         art->(dbSeek( Str(ang->Artikelnr,6) ))
         hUsers[ang->Buyer] += Str(ang->Angnr, 6) + " " + DtoC(ang->Datum)+" "+ang->Kundma+ " " + ang->Matchcode + " " + PadL(Transform(ang->VkQty, Me(art->Me)),12) + " " + art->Me  + CRLF
      ENDIF   
      ang->(dbSkip())
   ENDDO

   // Check if there are any Angebote to send
   FOR EACH cEmailContent IN hUsers
      buy->(dbGoto(cEmailContent:__eNumKey()))      

      //Add header to email content
      
      cEmailContent := Pad("Nr.",6) + " "+Pad("Datum", 8) + " "+Pad("Kunde",8)+" "+Pad("Artikel", 25) + " "+PadL("Menge", 12) + " "+Space(4) + CRLF + cEmailContent
      cEmailContent := "Du hast folgende Angebote, die bereits „lter als "+LTrim(Str(nDaysAgo))+" Tage und noch nicht angeboten sind:" + CRLF + CRLF +cEmailContent

      // Send the email
      SendMail({{Trim(buy->Email),Trim(buy->Buyer)}}, "Deine ausstehenden Angebote", cEmailContent)
      
   NEXT

RETURN NIL