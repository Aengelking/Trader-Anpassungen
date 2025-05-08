PROC RUN_REP_INFO
//dStart := Date()-365  //one year
//dStart := Date()-7  //one week
LOCAL dStart := Date()-Dow(Date())-If(DoW(Date())>=6,0,7)  //last week
LOCAL dEnd := dStart+7
LOCAL hReps,aTo
LOCAL hKunden := {=>},hKunde
LOCAL cName
LOCAL lF,cMe,lQtyOnly
LOCAL hRep
LOCAL aIDS,oExtra,nKunde,oUser
LOCAL bNEwRep,cRep

CLS

NetUse("engkund","ku",.F.,0)

NetUse("engauf","auf",.F.,0)
auf->(dbSetOrder( 9 )) //kundma+dtos(besda)

NetUse("artikel","art",.F.,0)

NetUSe("notes","nts",.F.,0)
nts->(dbSetOrder( 1 ))

NetUse("angebot","ang",.F.,0)
ang->(dbSetOrder( 7 ))

NetUse("rep","rep",.F.,0)	

hReps := {=>}

bNewRep := {|cRep,cName,cEmail|
IF ! HHaskEy(hReps,cRep)
   cEmail := "amos.engelking@engelking.de"
   hReps[cRep] := {"TEXT"=>"","TO"=>{cEmail,Trim(cName)},"NAME"=>cName}
   hReps[cRep]:Text += "Hallo "+cName
   hReps[cRep]:Text += t("<p>nachfolgend die Aktivitäten Deiner Kunden in der Zeit vom "+DToC(dStart)+" bis "+DToC(dEnd)+"<p>")
ENDIF
}


ku->(dbSetFilter({|| ! Empty(ku->Rep)},"!Empty(rep)"))
ku->(dbSetOrder( 2 ))
ku->(dbSeek( "K" ))

Do While ! ku->(Eof())
   ? ku->Kunde,ku->Rep
   
   rep->(dbSeek( Str(ku->Rep,2) ))
   IF rep->Buyer != 0 //Nur interne Vertreter
      IF ! HHasKey(hKunden,ku->Nummer)
         hKunden[ku->Nummer] := {"TEXT"=>"","REPS"=>{}}
      ENDIF  
      cRep := "AD"+LTrim(Str(ku->Rep))
      Aadd(hKunden[ku->Nummer]["REPS"],cRep)
      Eval(bNewRep,cRep,RepGetName(ku->Rep),RepGetEmail(ku->Rep))
   ENDIF   
   ku->(dbSkip())
ENDDO
ku->(dbClearFilter())

aIDS := GetIdsWithExtraField("KU","KAM")
ku->(dbSetOrder( 8 ))
FOR EACH nKunde IN aIDS
   ? nKunde
   oExtra := ku->(ExtraData():New(nKunde))
   IF oExtra:KAM != 0 
      ku->(dbSeek( Str(nKunde,6) ))
      
      oUser := User():New()
      oUser:Load(oExtra:KAM)

      IF ! HHasKey(hKunden,nKunde)
         hKunden[nKunde] := {"TEXT"=>"","REPS"=>{}}
      ENDIF  
      cRep := "KAM"+LTrim(Str(oExtra:KAM))
      Aadd(hKunden[nKunde]["REPS"],cRep)
      Eval(bNewRep,cRep,oUser:FirstName,Trim(oUser:Email))
   ENDIF
NEXT

ku->(dbSetOrder( 8 ))
FOR EACH hKunde IN hKunden
   ku->(dbSeek( Str(hKunde:__eNumKey(),6) ))      
   ang->(dbSeek( ku->Kunde ))
   lF := .T.
   Do While ang->KundMA == ku->Kunde
      If ang->Besda >= dStart .AND. ang->Besda <= dEnd
         art->(dbSeek( ang->Matchcode ))
         cMe := Me(art->me)
         If lF
            hKunde["TEXT"] += "<h3>"+t("Angebote")+"</h3>"
            hKunde["TEXT"] += "<table border='1'><tr><th>Nr.</th><th>Menge</th><th>Artikel</th><th>Preis</th><th>Gesamt</th></tr>"
            lF := .F.
         Endif
            lQtyOnly := .F.
            If (ang->vkqty > 0 .OR. ang->vkpr > 0) .AND. (!art->prmatch .AND. empty(ang->artikel))
               lQtyOnly := .T.
            Endif
            If ang->VkPr > 0
               hKunde["TEXT"] += "<tr><td>"+If(lQtyOnly,"",Str(ang->Angnr))+"</td><td>"+LTrim(Transform(ang->VkQty,cMe))+" "+art->Me+"</td><td>"+If(!lQtyOnly,Trim(ang->Matchcode),"")+"</td><td>"+Ltrim(Str(ang->VkPr,12,2))+" / "+LTrim(Str(ang->Pe))+"</td><td>"+If(lQtyOnly,"",Ltrim(Str(ang->VkQty*ang->vkPr*(1-ang->Rabatt/100)/ang->Pe,12,2)))+"</td></tr>"
            Endif
         Endif
         ang->(dbSkip())
      Enddo
      If ! lF
         hKunde["TEXT"] += "</table>"
      Endif

      //? Trim(RepGetName(ku->Rep)),ku->Kunde
      auf->(dbSeek(ku->Kunde+Dtos(dStart),.T.))
      IF auf->Kundma == ku->Kunde .AND. auf->Besda >= dStart
         //? "Auftr„ge",ku->Kunde
      ENDIF
      lF := .T.
      Do While auf->Kundma == ku->Kunde .AND. auf->Besda >= dStart
         If auf->VkPr*auf->VkQty > 0 .AND. auf->Besda <= dEnd
            art->(dbSeek( auf->Matchcode ))
            cMe := Me(art->me)
            If lF
               hKunde["TEXT"] += "<h3>"+t("Aufträge")+"</h3>"
               hKunde["TEXT"] += "<table border='1'><tr><th>Nr.</th><th>Menge</th><th>Artikel</th><th>Preis</th><th>Gesamt</th></tr>"
               lF := .F.
            Endif
            hKunde["TEXT"] += "<tr><td>"+Str(auf->Abnr)+"</td><td>"+LTrim(Transform(auf->VkQty,cMe))+" "+art->Me+"</td><td>"+Trim(auf->Matchcode)+"</td><td>"+Ltrim(Str(auf->VkPr,12,2))+" / "+LTrim(Str(auf->Pe))+"</td><td>"+Ltrim(Str(auf->VkQty*auf->vkPr*(1-auf->Rabatt/100)/auf->Pe,12,2))+"</td></tr>"
         Endif
         auf->(dbSkip())
      Enddo
      If ! lF
         hKunde["TEXT"] += "</table>"
      Endif
    
    
    nts->(dbSeek( ku->Kunde ))
   lF := .T.
   Do While nts->Matchcode == ku->Kunde .AND. nts->Date >= dStart
      If nts->Date <= dEnd
         If lF
            hKunde["TEXT"] += "<h3>"+t("Notizen")+"</h3>"
            hKunde["TEXT"] += "<table border='1'><tr><th>Datum</th><th>Art</th><th>Inhalt</th></tr>"
            lF := .F.
         Endif
         hKunde["TEXT"] += "<tr><td>"+DToC(nts->Date)+"</td><td>"
         hKunde["TEXT"] += NoteType(nts->Type)
         If nts->Buyer != 0
            hKunde["TEXT"] += "<br>"+Trim("von: "+Buy(nts->Buyer,.T.))
         Endif
         If nts->Person != 0
            hKunde["TEXT"] += "<br>"+Trim(If(nts->Type=="VISIT","bei","mit")+": "+PERSAY(nts->Person,.T.))
         Endif
         hKunde["TEXT"] += "</td><td>"+StrTran(nts->Note,Chr(13),"<br>")+"</td></tr>"
      Endif

      nts->(dbSkip())
   Enddo
   If ! lF
      hKunde["TEXT"] += "</table>"
   Endif

NEXT

FOR EACH hKunde IN hKunden
   ku->(dbSeek( Str(hKunde:__eNumKey(),6) ))
   FOR EACH cRep IN hKunde:Reps
      hReps[cRep]:Text += "<h2>"+Trim(Trim(ku->Name1)+" "+ku->Name2)+" ("+ku->Kunde+")"+"</h2>"
      hReps[cRep]:Text += hKunde:Text
      hReps[cRep]:Text += "<br>"

   NEXT
NEXT

FOR EACH hRep IN hReps   
   SendMail(hRep:To,t("Information über Kunden "+DToC(dStart)+" bis "+DToC(dEnd)),hRep:Text,{},.F.,0,.T.)
NEXT

? "Press any key..."
Sinkey(0)
