NetUse("englsre","re",.F.,0)
re->(dbSetORder(2)) //str(reposnr)+Kunde
re->(dbSeek( Str(0,3) ))

NetUse("engkund","ku")
ku->(dbSetOrder( 1 ))

Netuse("skontoa","sk")

LX_Start()
CLS

Do While re->Reposnr == 0 .AND. ! re->(Eof())
    IF re->Poswt > 0 .AND. re->Transfer .AND. re->Rechdat >= Date()-365 .AND. Empty(re->PayDate)
        IF sk->(IsPrepay(re->Skonto)) 
            IF re->PosWt < re->AoQty
              re->(Rec_Lock())
              re->Paydate := re->Rechdat
              re->(dbUnLock())
            ENDIF
        ELSE
        ku->(dbSeek( re->Kunde+"K" ))
         hOP := LX_GetOffenerPosten(ku->Nummer,re->Rechnr)
         IF Len(hOP) == 0
            ? re->Rechnr,LX_GetErrorMessage()
         ELSEIF Len(hOP:aZahlungen) == 0
            //? re->Rechnr,"keine Zahlung"
         ELSE
            ? re->Rechnr,hOp:dLetzteZahlung
            re->(Rec_Lock())
            re->PayDate := hOp:dLetzteZahlung
            re->(dbUnLock())
         ENDIF
         ENDIF
    ENDIF
    re->(dbSkip())
Enddo

? "BEENDET"
Inkey(0,128)