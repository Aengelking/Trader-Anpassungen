FUNCTION HOOK_GET_FREIGABE_NEXT_LEVEL(cState,nArtnr,nSupplier)
   LOCAL oArt := Artikel():New()
   oArt:Load(nArtnr)

   //if we are here then the product has a drawing number

   //{"UNT"=>"Unterlagen","UNTK"=>"Unt. v. Kunden","MUS"=>"Muster","KU"=>"Vom Kunden"}
   IF nSupplier == 0 //interne Produktion
      IF oArt:Type == "UNFER"
         RETURN "DONE"
      ELSE
         IF cState == "" .AND. ! oArt:KuZeichnun
            RETURN "UNTK"
         ELSEIF cState == "UNTK" .OR. (cState == "" .AND. oArt:KuZeichnun)
            RETURN "KU"
         ENDIF
      ENDIF
   //ELSEIF Trim(oArt:Gruppe) == "XX" .AND. Trim(oArt:Type) == "RHB" //Drehteile etc., hier gibt es keinen Freigabeprozess
     // RETURN "DONE"
   ELSE //Kaufteil oder externe Prodkution
      //If Left(oArt:Gruppe,2) == "KO" //Konfektion (frÅher war die Zeichnungsfreigabe nur bei Konfektionen notwendig, das macht aber keinen Sinn ae 10.10.19)      
         If cState == "" .AND. ! oArt:KuZeichnun  .AND. Trim(oArt:Type) == "WARE"//keine Kundenzeichnung, dann muss diese vom Kunden freigegeben werden, aber nur wenn es Ware ist, d.h. RHB und UNFERT nicht
            Return "UNTK"
         Elseif Left(oArt:Gruppe,2) == "KO" .AND. oArt:Gruppe != "KONK"  .AND. (cState == "" .OR. cState == "UNTK") //Fremd.-Unterlagen m¸ssen durch uns freigegeben werden, auﬂer bei Netzzuleitungen
            Return "UNT"
         Endif
      //Endif
      IF cState == "" .OR. cState == "UNT" .OR. cState == "UNTK"      
         RETURN "MUS"
      ELSEIF cState == "MUS" .AND. Trim(oArt:Type) == "WARE" .AND. (Left(oArt:Matchcode,2) $ "QX KS" .OR. "TEST" $ oArt:Matchcode) //nur bei Kundenspez. Artikeln         
         RETURN "KU"
      ENDIF
   ENDIF

Return "DONE" //default