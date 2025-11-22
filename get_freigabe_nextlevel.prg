FUNCTION HOOK_GET_FREIGABE_NEXT_LEVEL(cState,nArtnr,nSupplier,lNextFrei)
   //LOCAL nSec := Seconds()
   LOCAL oArt := Artikel():New()
   oArt:Load(nArtnr)

   Default(@lNextFrei,.T.) //backwards compatibility

   //if we are here then the product has a drawing number
   //{"UNT"=>"Unterlagen","UNTK"=>"Unt. v. Kunden","MUS"=>"Muster","KU"=>"Vom Kunden"}
   IF Left(oArt:Matchcode,2) == "BA" .OR. Trim(oArt:Matchcode) $ {"KS28074/1","KS36981/1","KS36981/2","KS36981/3","KS36981/4","KS36981/5","KS36981/6","KS36981/7";
                                             ,"KS36981/8","KS36981/9","KS36981/10","KS36981/11","KS36981/12","KS36981/13","KS36981/17","KS36981/19"}
      IF cState == "" .OR. cState == "UNTK" //UNTK only for existing parts where we have alreeady started
         RETURN "ZNG"
      ELSE
         RETURN "DONE"
      ENDIF
   ELSEIF nSupplier == 0 //interne Produktion
      IF oArt:Type == "UNFER"
         RETURN "DONE"
      ELSE
         IF cState == "" .AND. ! oArt:KuZeichnun
            RETURN "UNTK"
         ELSEIF cState == "UNTK" .OR. (cState == "" .AND. oArt:KuZeichnun)
            RETURN "KU"
         ENDIF
      ENDIF   
   ELSE //Kaufteil oder externe Prodkution
      /*IF Tr_Getini(28) == 9 .AND. ! lNextFrei
         Alert(cState)
      ENDIF*/
      
      IF cState == "" .AND. Trim(oArt:Type) == "WARE"
         RETURN "VMU"
      ELSEIf cState == "VMU" .AND. ! oArt:KuZeichnun  .AND. Trim(oArt:Type) == "WARE"//keine Kundenzeichnung, dann muss diese vom Kunden freigegeben werden, aber nur wenn es Ware ist, d.h. RHB und UNFERT nicht
         RETURN "UNTK"
      Elseif oArt:Gruppe != "KANK"  .AND. (cState == "VMU" .OR. cState == "UNTK") //Fremd.-Unterlagen m¸ssen durch uns freigegeben werden, auﬂer bei Netzzuleitungen
         RETURN "UNT"
      ELSEIF cState == "UNT" .OR. cState == "UNTK" //.OR. cState == "MUS" .AND. 
         RETURN  "MUS"
      ELSEIF cState == "MUS" .AND. Trim(oArt:Type) == "WARE" .AND. (Left(oArt:Matchcode,2) $ "QX KS" .OR. "TEST" $ oArt:Matchcode) //nur bei Kundenspez. Artikeln         
         IF ! lNextFrei //Kunde hat Muster abgelehnt, dann mÅssen wir neue Muster freigeben
            RETURN "MUS"
         ELSE
            RETURN "KU"
         ENDIF
      ENDIF

   ENDIF
   
   //? 
   //@ Row(),92 SAY Str(Seconds()-nSec)

Return "DONE" //default