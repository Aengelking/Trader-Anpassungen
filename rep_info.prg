PROC RUN_REP_INFO
//dStart := Date()-365  //one year
//dStart := Date()-7  //one week
LOCAL dStart := Date()-Dow(Date())-If(DoW(Date())>=6,0,7)  //last week
LOCAL dEnd := dStart+7
LOCAL hReps

NetUse("engkund","ku",.F.,0)
ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))

NetUse("engauf","auf",.F.,0)
auf->(dbSetOrder( 9 )) //kundma+dtos(besda)

NetUse("artikel","art",.F.,0)

NetUSe("notes","nts",.F.,0)
nts->(dbSetOrder( 1 ))

NetUse("angebot","ang",.F.,0)
ang->(dbSetOrder( 7 ))

NetUse("rep","rep",.F.,0)	

hReps := {=>}

Select("ku")
SET FILTER TO ! Empty(ku->Rep)

Do While ! ku->(Eof())
   If ! Empty(ku->Rep)
      ang->(dbSeek( ku->Kunde ))
      lF := .T.
      Do While ang->KundMA == ku->Kunde
         If ang->Besda >= dStart .AND. ang->Besda <= dEnd
            If ! HHasKey(hReps,ku->Rep)
               hReps[ku->Rep] := {=>}
            Endif
            If ! HHasKey(hReps[ku->Rep],ku->Kunde)
               hReps[ku->Rep][ku->Kunde] := ""
            Endif
            art->(dbSeek( ang->Matchcode ))
            cMe := Me(art->me)
            If lF
               hReps[ku->Rep][ku->Kunde] += "<h3>"+t("Angebote")+"</h3>"
               hReps[ku->Rep][ku->Kunde] += "<table border='1'><tr><th>Nr.</th><th>Menge</th><th>Artikel</th><th>Preis</th><th>Gesamt</th></tr>"
               lF := .F.
            Endif
            lQtyOnly := .F.
            If (ang->vkqty > 0 .OR. ang->vkpr > 0) .AND. (!art->prmatch .AND. empty(ang->artikel))
               lQtyOnly := .T.
            Endif
            If ang->VkPr > 0
               hReps[ku->Rep][ku->Kunde] += "<tr><td>"+If(lQtyOnly,"",Str(ang->Angnr))+"</td><td>"+LTrim(Transform(ang->VkQty,cMe))+" "+art->Me+"</td><td>"+If(!lQtyOnly,Trim(ang->Matchcode),"")+"</td><td>"+Ltrim(Str(ang->VkPr,12,2))+" / "+LTrim(Str(ang->Pe))+"</td><td>"+If(lQtyOnly,"",Ltrim(Str(ang->VkQty*ang->vkPr*(1-ang->Rabatt/100)/ang->Pe,12,2)))+"</td></tr>"
            Endif
         Endif
         ang->(dbSkip())
      Enddo
      If ! lF
         hReps[ku->Rep][ku->Kunde] += "</table>"
      Endif


      //? Trim(RepGetName(ku->Rep)),ku->Kunde
      auf->(dbSeek(ku->Kunde+Dtos(dStart),.T.))
      IF auf->Kundma == ku->Kunde .AND. auf->Besda >= dStart
         //? "Auftr„ge",ku->Kunde
      ENDIF
      lF := .T.
      Do While auf->Kundma == ku->Kunde .AND. auf->Besda >= dStart
         If auf->VkPr*auf->VkQty > 0 .AND. auf->Besda <= dEnd
            If ! HHasKey(hReps,ku->Rep)
               hReps[ku->Rep] := {=>}
            Endif
            If ! HHasKey(hReps[ku->Rep],ku->Kunde)
               hReps[ku->Rep][ku->Kunde] := ""
            Else
               //hReps[ku->Rep][ku->Kunde] += "<br>"
            Endif
            art->(dbSeek( auf->Matchcode ))
            cMe := Me(art->me)
            If lF
               hReps[ku->Rep][ku->Kunde] += "<h3>"+t("Aufträge")+"</h3>"
               hReps[ku->Rep][ku->Kunde] += "<table border='1'><tr><th>Nr.</th><th>Menge</th><th>Artikel</th><th>Preis</th><th>Gesamt</th></tr>"
               lF := .F.
            Endif
            hReps[ku->Rep][ku->Kunde] += "<tr><td>"+Str(auf->Abnr)+"</td><td>"+LTrim(Transform(auf->VkQty,cMe))+" "+art->Me+"</td><td>"+Trim(auf->Matchcode)+"</td><td>"+Ltrim(Str(auf->VkPr,12,2))+" / "+LTrim(Str(auf->Pe))+"</td><td>"+Ltrim(Str(auf->VkQty*auf->vkPr*(1-auf->Rabatt/100)/auf->Pe,12,2))+"</td></tr>"
         Endif
         auf->(dbSkip())
      Enddo
      If ! lF
         hReps[ku->Rep][ku->Kunde] += "</table>"
      Endif
    Endif
    
    nts->(dbSeek( ku->Kunde ))
   lF := .T.
   Do While nts->Matchcode == ku->Kunde .AND. nts->Date >= dStart
      If nts->Date <= dEnd
         If ! HHasKey(hReps,ku->Rep)
            hReps[ku->Rep] := {=>}
         Endif
         If ! HHasKey(hReps[ku->Rep],ku->Kunde)
            hReps[ku->Rep][ku->Kunde] := ""
         Endif
         If lF
            hReps[ku->Rep][ku->Kunde] += "<h3>"+t("Notizen")+"</h3>"
            hReps[ku->Rep][ku->Kunde] += "<table border='1'><tr><th>Datum</th><th>Art</th><th>Inhalt</th></tr>"
            lF := .F.
         Endif
         hReps[ku->Rep][ku->Kunde] += "<tr><td>"+DToC(nts->Date)+"</td><td>"
         hReps[ku->Rep][ku->Kunde] += NoteType(nts->Type)
         If nts->Buyer != 0
            hReps[ku->Rep][ku->Kunde] += "<br>"+Trim("von: "+Buy(nts->Buyer,.T.))
         Endif
         If nts->Person != 0
            hReps[ku->Rep][ku->Kunde] += "<br>"+Trim(If(nts->Type=="VISIT","bei","mit")+": "+PERSAY(nts->Person,.T.))
         Endif
         hReps[ku->Rep][ku->Kunde] += "</td><td>"+StrTran(nts->Note,Chr(13),"<br>")+"</td></tr>"
      Endif

      nts->(dbSkip())
   Enddo
   If ! lF
      hReps[ku->Rep][ku->Kunde] += "</table>"
   Endif

   ku->(dbSkip())
Enddo
nR := 1
Do While nR <= Len(hReps)
   nRep := HGetKEyAt(hReps,nR)
   IF nRep != 0
      ? Trim(RepGetName(nRep))
   ELSE
      ? "Allgemein"
   ENDIF
   cText := ""
   hRep := HGetValueAt(hReps,nR)
   nX := 1
   Do While nX <= Len(hRep)
      ku->(dbSeek( "K"+HGetKeyAt(hRep,nX) ))
      cText += "<h2>"+Trim(Trim(ku->Name1)+" "+ku->Name2)+" ("+ku->Kunde+")"+"</h2>"
      cText += hGetValueAt(hRep,nX)
      cText += "<br>"
      nX++
   Enddo
   cName := RepGetName(nRep)
   cIntro := "Hallo "+cName
   cIntro += t("<p>nachfolgend die Aktivitäten Deiner Kunden in der Zeit vom "+DToC(dStart)+" bis "+DToC(dEnd)+"<p>")
   cText := cIntro+cText
   aTo := {}   
   IF nRep != 0
      rep->(dbSeek( Str(nRep,2) ))
      IF rep->Buyer != 0 //Nur interne Vertreter
         Aadd(aTo,{RepGetEmail(nRep),Trim(cName)})   
      ENDIF
   ENDIF
   IF nRep == 0 //.OR. RepGetEmail(nRep) != "thimo.hamma@engelking.de"
      Aadd(aTo,{"thimo.hamma@engelking.de","Thimo Hamma",If(Len(aTo)==0,"TO","CC")})
   ENDIF
   Aadd(aTo,{"amos.engelking@engelking.de","Amos Engelking",If(Len(aTo)==0,"TO","CC")})
   SendMail(aTo,t("Information über Kunden "+DToC(dStart)+" bis "+DToC(dEnd)),cText,{},.F.,0,.T.)
   //SendMail({{"amos.engelking@engelking.de",Trim(cName)}},t("Information über Kunden "+DToC(dStart)+" bis "+DToC(dEnd)),cText,{},.F.,0,.T.)
   nR++
Enddo

ku->(dbClearFilter())
