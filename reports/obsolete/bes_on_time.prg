LOCAL dEnd := STOD(Str(Year(Date())-1,4)+"1231") //STOD(Str(2015,4)+"0831")
LOCAL dStart := STOD(Str(Year(Date())-1,4)+"0101") //STOD(Str(2014,4)+"0901") //AddMonth(Date(),-12)
LOCAL dDelDate
LOCAL hLief := {=>},hData
LOCAL aQuarters := {{0,0,0},{0,0,0},{0,0,0},{0,0,0}}

Head(HB_AnsiToOem("Lieferantenbewertung"))

NetUse("engbes","bes")
NetUse("lspos","lsp")
NetUse("ls","ls")
NetUse("qs","qs")

lsp->(dbSetOrder( 3 )) //besnr+bespos

@ 01,00 SAY "ab " GET dStart
@ 02,00 SAY "bis" GET dEnd
READ

IF LastKey() == 27
   RETURN
ENDIF

bes->(dbSeek( Str( 17000,6 ) ))

bAdd := {|cLiefma|
   IF ! HHasKey(hLief,cLiefma)
      hLief[cLiefma] := {"COUNT"=>0,"LATE"=>0,"QS"=>0}
   ENDIF
}

DO WHILE ! bes->(Eof()) .AND. Inkey() != 27
   IF bes->FolgeTo == 0
      lNoEk := bes->EkPr == 0
   ENDIF
   //? CalWd(bes->LTerm),CalWd(bes->LTerm) >= dStart
   IF CalWd(bes->LTerm) <= dEnd .AND. CalWd(bes->lTerm) >= dStart .AND. bes->GelQty > 0 .AND. ! lNoEk
      Eval(bAdd,bes->Liefma)
      hLief[bes->Liefma]["COUNT"]++

      aQuarters[Q(CalWd(bes->LTerm))][1]++

      lsp->(dbSeek( Str(bes->Besnr,6)+Str(bes->Posnr,3) ))
      dDelDate := CTOD("")
      DO WHILE lsp->Besnr == bes->Besnr .AND. lsp->Bespos == bes->Posnr
         ls->(dbSeek( lsp->Liefma+lsp->Beleg ))
         dDelDate := Max(dDelDate,ls->Datum)
         lsp->(dbSkip())
      ENDDO
      dLast := CalWD(bes->LTerm+Max(bes->Shiptime,1))+4  //end of the week

      //add Kulanztage excluding days when the firm is closed
      nAdded := 0

      nYear := Year(dLast)
      aDays := Hook("get_firmclosed",{nYear},{})

      DO WHILE AScan(aDays,dLast) != 0 .AND. nAdded < 2 //two days
         dLast := AddWorkingDays( dLast, 1, "BW", .T. )
         IF nYear != Year(dLast)
            nYear := Year(dLast)
            aDays := Hook("get_firmclosed",{nYear},{})
         ENDIF
         IF AScan(aDays,dLast) == 0
            nAdded++
         ENDIF
      ENDDO

      IF dLast < dDelDate
         hLief[bes->Liefma]["LATE"]++
         aQuarters[Q(CalWd(bes->LTerm))][2]++
         //IF Trim(bes->Liefma) == "TECHNO"
         ? bes->Liefma,bes->Besnr,bes->Posnr,bes->LTerm,dLast,dDelDate
         //ENDIF
      ENDIF
   ENDIF
   bes->(dbSkip())
ENDDO

qs->(dbSetFilter( {|| qs->Datum >= dStart .AND. qs->Datum <= dEnd .AND. ! Empty(qs->Liefma)}))
qs->(dbGoTop())
DO WHILE ! qs->(EOF())
   ? qs->Nummer,qs->Liefma
   Eval(bAdd,qs->Liefma)
   hLief[qs->Liefma]["QS"]++
   aQuarters[Q(qs->Datum)][3]++
   qs->(dbSkip())
ENDDO

//Inkey(0,128)

CLS
? "Lieferantenbewertung "+DtoC(dStart)+" bis "+DtoC(dEnd)
? Pad("Lieferant",8),PadL("Anzahl",6),PadL(t("Spät"),6),Space(6),PadL("QS",6)
FOR EACH hData IN hLief
   IF hData:Count >= 50
      ? hData:__enumKey(),Str(hData:Count,6),Str(hData:Late,6),Str((hData:Late)/hData:Count*100,6,2)+"%",Str(hData:Qs,6),Str(hData:QS/hData:Count*100,6,2)+"%"
   ENDIF
NEXT

?
? "Quartal",PadL("Anzahl",6),PadL(t("Spät"),6),Space(6),PadL("QS",6)
FOR nQ := 1 TO 4
   ? Str(nQ,1),Space(5),Str(aQuarters[nQ,1],6),Str(aQuarters[nQ,2],6),Str(aQuarters[nQ,2]/Max(aQuarters[nQ,1],1)*100,6,2)+"%",Str(aQuarters[nQ,3],6),Str(aQuarters[nQ,3]/Max(aQuarters[nQ,1],1)*100,6,2)+"%"
NEXT

SInkey(0,128)

STATIC FUNCTION Q(dDate)
   LOCAL nQ

   IF Month(dDate) >= 10
      nQ := 4
   ELSEIF Month(dDate) >= 7
      nQ := 3
   ELSEIF Month(dDate) >= 4
      nQ := 2
   ELSE
      nQ := 1
   ENDIF
RETURN nQ

