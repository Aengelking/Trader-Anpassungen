FUNCTION HOOK_GET_FREIGABE_NEXT_LEVEL(cState,nArtnr,nSupplier)
   //LOCAL nSec := Seconds()
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
   ELSE //Kaufteil oder externe Prodkution
      If cState == "" .AND. ! oArt:KuZeichnun  .AND. Trim(oArt:Type) == "WARE"//keine Kundenzeichnung, dann muss diese vom Kunden freigegeben werden, aber nur wenn es Ware ist, d.h. RHB und UNFERT nicht
         RETURN "UNTK"
      Elseif /*Left(oArt:Gruppe,2) == "KO" .AND.*/ oArt:Gruppe != "KONK"  .AND. (cState == "" .OR. cState == "UNTK") //Fremd.-Unterlagen müssen durch uns freigegeben werden, außer bei Netzzuleitungen
         RETURN "UNT"
      Endif

      /*IF Tr_Getini(28) == 9
         Alert(cState)
      ENDIF*/

      IF cState == "" .OR. cState == "UNT" .OR. cState == "UNTK"      
         RETURN  "MUS"
      ELSEIF cState == "MUS" .AND. Trim(oArt:Type) == "WARE" .AND. (Left(oArt:Matchcode,2) $ "QX KS" .OR. "TEST" $ oArt:Matchcode) //nur bei Kundenspez. Artikeln         
         RETURN "KU"
      ENDIF
   ENDIF
   
   //? 
   //@ Row(),92 SAY Str(Seconds()-nSec)

Return "DONE" //default