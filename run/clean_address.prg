PROCEDURE HRBMAIN
LOCAL dMaxDate //:= StoD("19991231") //Date()-365
LOCAL cFilter
//LOCAL cCompForms := "PRIVA-EK-EINZE-EU"
LOCAL hMaxAges := {;
   "ANGEBOT"=>11,;
   "AUFTRAG"=>11,;
   "RECHNUNG"=>11,;
   "VERSAND"=>11,;
   "ZAHLUNG"=>11,;
   "ADRESSE"=>11;
}
//LOCAL nNr,nRec
//LOCAL dDate,oRechnung
LOCAL aList
//LOCAL oAuftrag,lDelete,lClean
//LOCAL nCount
LOCAL cKunde,hKunden,oRechnung
LOCAL hWrong
LOCAL nRec,aFiles
LOCAL nNext,nAngnr

IF GetEnv("username") != "Administrator"
   //TR_MsgBox("Needs to run as Administrator to clear archived files")
   //RETURN
ENDIF

Head("Alte Adressdaten lï¿½schen")

//Kontaktpersonen
/* Dateien: 
engauft
auftrag
Bestellung
angebot
notes
lagerne
muster
*/

//Kunden
/*
enras
engbew
engabg

*/

//Mitarbeiter
/*
ups
engauft
bestellung
werkauf
watimes
lagerne
engabg
engbew
*/

NetUse("artikel","art")
NetUse("engkund","ku")
NetUse("angebot","ang")

/*

NetUse("auftrag","ab")
NetUse("engauf","auf")
NetUse("rechnung","reh")
NetUse("englsre","re")
NetUse("ups","ups")
NetUse("enras","ras")
NetUse("skontoa","sk")
NetUse("engbew","bew")
NetUse("buyer","buy")*/

art->(dbSetOrder( 2 ))
ku->(dbSetOrder( 2 ))

//Net_use("Y:\Dokumente und Einstellungen\Amos\Eigene Dateien\trader\enras","ras",.F.,0)

/*
   ANGEBOTE
*/
aList := {}

cFilter := 'Besda < StoD(Str(Year(Date())-'+LTrim(Str(hMaxAges:Angebot))+',4)+"0101")'
ang->(dbSetFilter({|| ang->(&(cFilter)) },cFilter))
ang->(dbGoTop())
DO WHILE ! ang->(EOF()) .AND. LastKey() != 27
   ku->(dbSeek( "K"+ang->Kundma ))
   ang->(dbSkip(1))
   nNext := ang->(Recno())
   ang->(dbSkip(-1))
   IF Trim(ang->Kundma) == "SELF"
      ? ang->Angnr,ang->Besda,Trim(Trim(ku->Name1)+" "+ku->Name2)
      IF ! ang->Angnr $ aList
            Aadd(aList,ang->Angnr)
      ENDIF
      //ang->(OverwriteAndDelete())
      ? "DATENSATZ GELOESCHT"
      
      //SINKEY(0)
   ELSEIF  ang->Besda <= StoD(Str(Year(Date())-hMaxAges:Angebot,4)+"0101") //Max. alter erreicht
      ? ang->Angnr,ang->Besda,Trim(Trim(ku->Name1)+" "+ku->Name2),ku->Compform,"Angebot l”schen"
      IF ! ang->Angnr $ aList
         Aadd(aList,ang->Angnr)
      ENDIF
      
   /*ELSEIF art->(dbSeek( Str(ang->Artikelnr,6) )) .AND. art->Obsolete
      ? ang->Angnr,ang->Besda,Trim(Trim(ku->Name1)+" "+ku->Name2),art->Matchcode,"ABGEKšNDIGT - Pos. gel”scht"
      IF ! ang->Angnr $ aList
            Aadd(aList,ang->Angnr)
      ENDIF
      //ang->(OverwriteAndDelete())
   ELSE //ansonsten nur Kontaktpersonen lÃ¶schen
      ? ang->Angnr,ang->Besda,Trim(Trim(ku->Name1)+" "+ku->Name2),ku->Compform,"Personen löschen"
      /*ang->(Rec_Lock())
      ang->Person := 0
      ang->Buyer := 0
      ang->(dbUnLock())*/
   ENDIF
   IF Upper(Chr(Inkey())) == "P"
      Sinkey(0)
   ENDIF

   ang->(dbGoto(nNext))
ENDDO
ang->(dbClearFilter())
FOR EACH nAngnr IN aList
   //IF ! ang->(dbSeek(Str(nAngnr,6),.T.)) .OR. ang->Angnr != nAngnr
      //delete archived file
      aFiles := Hook("get_archive_files",{{"ANG"=>ang->Angnr}})
      IF Len(aFiles) != 0
         ? ValToPrg(aFiles)
      ENDIF
   //ENDIF

NEXT

Sinkey(0)
RETURN

/*

Zahlungen komprimieren.

Dies muss vor der Rechnungsl”schung erfolgen

*/
/*CLS
hKunden := {=>}
cFilter := 'PayDate < StoD(Str(Year(Date())-'+LTrim(Str(hMaxAges:Zahlung))+',4)+"0101")'
ras->(dbSetFilter({|| ras->(&(cFilter)) },cFilter))
ras->(dbGoTop())
DO WHILE ! ras->(EOF()) .AND. LastKey() != 27
   ku->(dbSeek( "K"+ras->Kunde ))
   IF ku->CompForm $ cCompForms .OR. Empty(ku->Compform)
      ? ras->Datum,ras->Kunde,ras->Betrag,ku->Compform,"l”schen"
      IF ! HHasKey(hKunden,ras->Kunde)
         hKunden[ras->Kunde] := 0
      ENDIF
      IF ras->Rechnr == 0
         hKunden[ras->Kunde] += Round(ras->Betrag*Currate(ras->Money,"V")/Currate(ku->Money,"V"),2)
      ENDIF
      //ras->(OverwriteAndDelete())
      IF Upper(Chr(Inkey())) == "P"
         Sinkey(0)
      ENDIF   
   ENDIF
   ras->(dbSkip())
ENDDO
hWrong := {=>}
ras->(dbClearFilter())
FOR EACH cKunde IN HGetKeys(hKunden)
   ku->(dbSeek("K"+cKunde))
   
   cFilter := 'Rechdat < StoD(Str(Year(Date())-'+LTrim(Str(hMaxAges:Zahlung))+',4)+"0101")'
   reh->(dbSetOrder(2))
   reh->(dbSetFilter({|| reh->(&(cFilter)) },cFilter))
   reh->(dbSeek(cKunde))
   hWrong[cKunde] := hKunden[cKunde]
   DO WHILE ! reh->(Eof()) .AND. reh->Kunde == cKunde
      oRechnung := Rechnung():New()
      oRechnung:Load(reh->Rechnr)
      IF sk->(IsPrepay(reh->Skonto))
         hKunden[cKunde] -= Round(reh->Brutto*Currate(reh->Money,"V",reh->Rechdat)/Currate(ku->Money,"V",reh->Rechdat),2)
         hWrong[cKunde] -= reh->Brutto            
      ELSEIF ! oRechnung:Bezahlt //not marked as payed, we ignore these - we are talking about 10 Year old invoices after all!
        // hKunden[cKunde] -= Round((reh->Brutto-reh->ZAHLBETRAG)*Currate(reh->Money,"V")/Currate(ku->Money,"V"),2)
      ENDIF
      reh->(dbSkip())
   ENDDO
   reh->(dbClearFilter())
   
   //2009 the "old" prepayments where changed and there was a total amount created, if the date is before the 1.1.09 then we correct this amount
   IF Year(Date())-hMaxAges:Zahlung < 2009
      cFilter := 'Trim(Bemerkung) == "Abgleich alte Vorkassen"'
      ras->(dbSetOrder(1))
      ras->(dbSetFilter({|| ras->(&(cFilter)) },cFilter))
      IF ras->(dbSeek( cKunde )) 
         IF Round(hKunden[cKunde],2) == ras->Betrag*-1 .OR. hWrong[cKunde] == ras->Betrag*-1  //some of them where set wrong DEM/EUR Problem
            ? cKunde, "ABGLEICH L™SCHEN"
            hKunden[cKunde] := 0
            //ras->(OverwriteAndDelete())
         ELSE
            ? cKunde,"ABGLEICH ANPASSEN",ras->Betrag ,hKunden[cKunde],ras->Betrag+hKunden[cKunde]
            ras->(Rec_Lock())
            //ras->Betrag += hKunden[cKunde]
            ras->(dbUnLock())
            hKunden[cKunde] := 0
         ENDIF
      ENDIF
      ras->(dbClearFilter())
      IF Round(hKunden[cKunde],2) != 0 
         ? cKunde,hKunden[cKunde],StoD(Str(Year(Date())-hMaxAges:Zahlung,4)+"0101"),hWrong[cKunde]
      ENDIF
   ENDIF
NEXT*/


/**
   RECHNUNGEN
*/

/*cFilter := 'Empty(kunde)'
reh->(dbSetFilter({|| reh->(&(cFilter)) },cFilter))
reh->(dbGoTop())
DO WHILE ! reh->(EOF()) .AND. LastKey() != 27
   nRec := reh->(Recno())

   oRechnung := Rechnung():New(.F.)
   oRechnung:Load(reh->Rechnr)

   ? reh->Rechnr,oRechnung:Positions:GetFirstRecord():AbNr
   ab->(dbSeek(Str(oRechnung:Positions:GetFirstRecord():AbNr,6),.T.))
   IF oRechnung:Positions:GetFirstRecord():AbNr == ab->Abnr
      oRechnung:Kunde := ab->Kundma
      oRechnung:Save()
      ?? ab->Kundma
   ENDIF

   reh->(dbSkip())
ENDDO*/

//aList := {}
/*ku->(dbSetOrder(8))
CLS
cFilter := 'Rechdat < StoD(Str(Year(Date())-'+LTrim(Str(hMaxAges:Rechnung))+',4)+"0101")'
reh->(dbSetFilter({|| reh->(&(cFilter)) },cFilter))
reh->(dbGoTop())
DO WHILE ! reh->(EOF()) .AND. LastKey() != 27
   nRec := reh->(Recno())

   oRechnung := Rechnung():New(.F.)
   oRechnung:Load(reh->Rechnr)
   
   aFiles := GetArchiveFiles( {"RE"=>oRechnung:Rechnr} )

   ? oRechnung:Kunde,oRechnung:Rechnr,IF(Len(aFiles)>0,"DATEIEN L™SCHEN","")
   
   IF oRechnung:oKunde:compForm $ cCompForms .OR. Empty(oRechnung:oKunde:compForm)
      //oRechnung:Kunde := ""
   ENDIF
   oRechnung:Person := 0
   oRechnung:Save()

   IF Upper(Chr(Inkey())) == "P"
      Sinkey(0)
   ENDIF
   reh->(dbGoTo(nRec))
   reh->(dbSkip())
ENDDO
reh->(dbClearFilter())*/

/*
Versandinformationen
*/
/*CLS
cFilter := 'Datum < StoD(Str(Year(Date())-'+LTrim(Str(hMaxAges:Versand))+',4)+"0101")'
ups->(dbSetFilter({|| ups->(&(cFilter)) },cFilter))
ups->(dbGoTop())
DO WHILE ! ups->(EOF()) .AND. LastKey() != 27
   ? ups->Datum,ups->Rechnr,ups->Nummer
   ups->(Rec_Lock())
   ups->Person := 0
   ups->(dbUnLock())
   IF Upper(Chr(Inkey())) == "P"
      Sinkey(0)
   ENDIF   
   ups->(dbSkip())
ENDDO
ups->(dbClearFilter())*/



//Check Sales Orders after Invoices have been cleaned, then we can check if the order is still needed for a invoice
/*CLS
re->(dbSetOrder(10))
cFilter := 'Besda < StoD(Str(Year(Date())-'+LTrim(Str(hMaxAges:Auftrag))+',4)+"0101")'
ab->(dbSetFilter({|| ab->(&(cFilter)) },cFilter))
ab->(dbGoTop())
DO WHILE ! ab->(EOF()) .AND. LastKey() != 27
   oAuftrag := Auftrag():New()
   IF Trim(oAuftrag:Kunde:compForm) $ cCompForms .OR. Empty(oAuftrag:Kunde:compForm)
      lDelete := .T.
      lClean  := .T.
      nCount := 0
      //data on an order is only removed. if all the invoices have been removed
      oAuftrag:Positions:Each({|oPos|
         nCount++
         IF oPos:GelQty != 0
            lDelete := .F. //only orders where never anything has been shipped will be deleted
         ENDIF
         IF re->(dbSeek( Str(oAuftrag:AbNr,6)+Str(oPos:Itmnr,3) )) .AND. ! Empty(re->Kunde)
            lClean := .F. //orders which do not have any invoices (with customer name) will be cleaned
         ENDIF
         RETURN .T.
      })
      IF lDelete .OR. lClean
         ? oAuftrag:Abnr,oAuftrag:Kundma,IF(lDelete,"L™SCHEN",IF(lClean,"SŽUBERN",""))+" "+LTrim(Str(nCount))
         IF lDelete
         ELSE
         ENDIF   
      ENDIF
   ENDIF
   IF Upper(Chr(Inkey())) == "P"
      Sinkey(0)
   ENDIF   
   ab->(dbSkip())
ENDDO
auf->(dbClearFilter())*/



//we will reinstate this at a later stage. After the records in the other DBs (e.g. quotes) have been deleted

IF Tr_MsgBox(t("Alte niemals genutzte Adressen lï¿½schen?"),,{"Nein","Ja"}) != 2 
   RETURN
ENDIF
cMaxDate := Str(Year(Date())-hMaxAges["ADRESSE"],4)+"0101"
dMaxDate := StoD(cMaxDate)
NetUse("engkund","ku")
ku->(dbSetOrder( 2 ))
ku->(dbSeek("K"))
re->(dbSetOrder(1))
nRow := Row()
DO WHILE ! ku->(EOF()) .AND. ku->Group == "K"
   cText := ""
   IF Empty(ku->KuSchutz) .AND. ku->K_SEIT < dMaxDate 
      
      re->(dbSetFilter({|| re->Rechdat >= dMaxDate },"Rechdat >= StoD('"+cMaxDate+"')"))
      IF re->(dbSeek( ku->Kunde ))
         re->(dbClearFilter())
         ? ku->Kunde,ku->Name1,ku->K_Seit, "Rechnung vorhanden"
      ELSE
         re->(dbClearFilter())
         IF Search_Matchcode( ku->Kunde,ku->Group, ku->Nummer, .T.,@cText,.F.) //berhaupt keine Eintr„ge, Adresse wird vollst„ndig gel”scht
         SetPos(nRow,0)
         ? ku->Kunde,ku->Name1,ku->K_Seit, "wird gel”scht"
         /*IF ! DeleteAddress(.F.,@cText)
            ?? "FEHLER",cText
         ENDIF*/
         ENDIF    
      ENDIF
      IF nRow < MaxRow()
         nRow++
      ENDIF
   ELSE
//      SetPos(nRow,0)
//      ? ku->Kunde,cText
   ENDIF
   IF Upper(Chr(Inkey())) == "P"
      Sinkey(0)
   ENDIF
   ku->(dbSkip())
ENDDO     

/*
   Mitarbeiter
*/
buy->(dbSetFilter({|| ! buy->Aktive .AND. ! Empty(buy->Buyer) },"! Aktive .AND, ! Empty(Buyer)"))
DO WHILE ! buy->(Eof())
   ? buy->(Recno()),buy->Buyer
   cFilter := 'Person == '+LTrim(Str(buy->(Recno())))
   reh->(dbSetFilter({|| reh->(&(cFilter)) },cFilter))
   reh->(dbGoTop())
   IF reh->Person == buy->(Recno())
      ?? " still used",reh->Rechnr
   ELSE
      ?? " not used in invoice"
   ENDIF
   reh->(dbClearFilter())

   //ups->(dbSetFilter({|| }))
   buy->(dbSkip())
ENDDO
buy->(dbClearFilter())



Sinkey(0)
RETURN 

STATIC FUNCTION OverwriteAndDelete() //function to overwrite the record and mark it for deletion, we need to add some cleanup routines (pack) at some point
   LOCAL nX
   LOCAL xNew,cType

   Rec_Lock()
    ? Alias(),FCount()
   FOR nX := 1 TO FCount()
      cType := FieldType(nX)
      xNew := ""
      IF cType == "N"
         xNew := 0
      ELSEIF cType == "D"
         xNew := StoD("")
      ELSEIF cType == "L"
         xNew := .F.
      ENDIF
//      ? FieldName(nX),FieldGet(nX),xNew
      FieldPut(nX,xNew)
   NEXT
   
   dbDelete()
   dbUnLock()

RETURN .T.