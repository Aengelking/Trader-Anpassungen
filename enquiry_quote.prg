/*
*  This function is used to send enquiries for a quote to the suppliers.
*  This will be done for all the items without a price
*  
*  How the supplier is selected:
*     - Any part supplier marked with a priority between 1 and 7 or the supplier has a level of at least 8 (Qualified Supplier)
*     - If the part is a manufacturing part and has a brice break
*        - the supplier on the wage item is used if it exists
*        - otherwise if there is a price brake on the part it is attempted to send an enquiry to all suppliers of the sub parts
*     - It does not check if the part has been relased with this supplier yet

** TODO **
* SHOULD WE? Check if we already have a price from the supplier for that quantity? -> YES
* Part list of supplied parts on the email when parts are manufactured
*/

PROC Run_Enguiry_Quote()
   LOCAL nAngebot := 45990
   LOCAL hSupplier
   LOCAL getlist := {}

   NetUse("engkund","ku")
   NetUse("angebot","ang")
   NetUse("artikel","art")
   NetUse("manufact","manu")
   NetUse("artlief","ali")
   NetUse("parts","part")

   ang->(dbSetOrder(1))
   art->(dbSetOrder( 2 ))
   ali->(dbSetOrder( 5 ))
   //ku->(dbSetOrder( 8 ))

   Head("Angebot anfragen")
   DO WHILE .T.
      @ 01,00 CLEAR
      @ 01,00 SAY "Angebot" GET nAngebot PICTURE "999999"
      READ
      IF LastKey() == 27
         EXIT
      ENDIF
      SetPos(2,0)
      hSupplier := {=>}
      IF ! ang->(dbSeek( Str(nAngebot,6) ))
         ? "Angebot nicht gefunden"    
         LOOP  
      ENDIF
      ? "Angebot: ",ang->Angnr
      DO WHILE ang->angnr == nAngebot
         
         IF ang->VkPr == 0         
            ? ang->ArtikelNr
            __AddToEnquiry( ang->ArtikelNr,ang->VkQty,hSupplier )
         ENDIF
         ang->(dbSkip())
      ENDDO

      ? ValToPrg(hSupplier)
      Sinkey(0)
   ENDDO
   RETURN

   FUNCTION __AddToEnquiry( nArtNr,nMenge,hSupplier )         
      LOCAL lSupplier,nArtikelnr
      LOCAL oExtra,aEnv
      art->(dbSeek( Str(nArtnr,6) ))
      IF Left(art->Matchcode,1) != "@";
          .AND. Left(art->Matchcode,4) != "TEXT";
          .AND. ! Trim(art->Matchcode) $ {"PORTO"}
         lSupplier := .F.
         nArtikelnr := 0

         //get the supplier for the part
         IF art->Bezug >= 5 //Fertigungsartikel
            ? "Fertigungsartikel: "+art->Matchcode
            IF part->(dbSeek( Str(art->ArtikelNr,6) )) 
               IF part->Pos == 0 //skip (old) header
                  part->(dbSkip())
               ENDIF               
               IF part->Pos == -1 .AND. ali->(dbSeek( Str(part->PartArt,6) ))                  
                  ? "Fremdteil: ",part->PartArt
                  nArtikelnr := part->PartArt                  
               ENDIF   
               aEnv := SaveEnv()
               IF art->Table != 0 //run through the list of parts
                  ? "Stckliste: "+art->Matchcode,part->ListArt,nArtnr               
                  DO WHILE part->ListArt == nArtnr .AND. ! part->(EOF())
                     IF part->Pos > 0 .AND. part->Qty+part->AddQty > 0
                        __AddToEnquiry( part->PartArt,CeilingMe(nMenge*part->Qty*part->Factor*(1+part->AddPercent)+part->AddQty,art->Me),hSupplier )
                     ENDIF
                     part->(dbSkip())
                  ENDDO
                  RestEnv(aEnv,.F.)
                  ? nArtikelNr,ali->Kunde
               ENDIF
            ENDIF
         ELSEIF ali->(dbSeek( Str(nArtnr,6) ))               
            nArtikelNr := nArtnr
         ENDIF
         IF nArtikelNr != 0
            DO WHILE ali->ArtikelNr == nArtikelNr .AND. ! ali->(EOF())
               ku->(dbSeek( ali->Kunde+"L" ))
               oExtra := ku->(ExtraData():New(ku->Nummer))
               IF (ali->Priority < 8 .OR. (ali->Priority == 8 /*.AND. ku->Nummer == manu->Address*/ .AND. Val(oExtra:Level) >= 8));
                  .AND. ali->Min <= nMenge
                  //hFreigabe := art->(GetFreigabeBesState(ku->Nummer))
                  //If hFreigabe:lBes .OR. ang->VkQty <=  hFreigabe:nMaxQty 
                     IF ! HHasKey(hSupplier,ali->Kunde)
                        hSupplier[ali->Kunde] := {}
                     ENDIF
                     //add position to list for enquiry
                     Aadd(hSupplier[ali->Kunde],{"artnr"=>nArtnr,"menge"=>nMenge})
                     lSupplier := .T.
                  //ENDIF
               ENDIF
               ali->(dbSkip())
            ENDDO
         ENDIF
         IF ! lSupplier
            //manual interaction required
            ? "No supplier found for article: "+art->Matchcode
         ENDIF
      ENDIF
   RETURN .T.