#include 'y:\hb34\include\inkey.ch'
#define DEBUG_PART "" //"p19294.GEH.V2.KPL.002"

PROCEDURE RUN_FREPPLE_IMPORT()
   //LOCAL cData := MemoRead(Path("import\frepple\manufacturingorder.csv"))
   LOCAL nX,nY
   LOCAL lInString := .F.
   LOCAL cCol,nQuoteCount := 0,hRow,aRow,aJob
   LOCAL aData := {},nCol,cChar,hMap
   LOCAL hItems := {=>},cMatch,aMatch,nExt
   LOCAL hSuppliers := {=>},cSupplier
   LOCAL hOrders := {=>},hRealQty := {=>},nAufno,hJobs := {=>}
   LOCAL nSt
   LOCAL aCSV,cFileName
   LOCAL cJob
   LOCAL nOrder,hJob,dStart,dEnd
   LOCAL bAddJobs,oRec   
   LOCAL oExtra,oArtExtra
   LOCAL aList,oBrowse
   LOCAL dOldEnd,dOldStart,lChange
   LOCAL bAddRowData,oWerk
   LOCAL aKWQty,nWeek,nKW,nQty
   LOCAL nColCount := MaxCol()+1
   LOCAL nRowCount := MaxRow()+1
   LOCAL nD
   LOCAL aText,nChoice
   LOCAL oBes,nBesnr
   LOCAL aWO
   LOCAL nLastPosnr

   LOCAL cQSStart := Trim(GetValue("FREPPLE_QS_JOBST","QS","QS job names start with"))   

   LOCAL oFrepple := GetFreppleApi()
   
   MEMVAR c_four,c_one

   //FOR nX := 1 TO 10
   IF nColCount < 186
      SetMode(nRowCount,nColCount+1)
      SetMode(nRowCount,nColCount+20)
   ENDIF
   //NEXT

   Head("Importing from Frepple")

   IF ! LockEntity("PPLIM",0)
      RETURN
   ENDIF


   NetUse("artikel","art")
   NetUse("werkauf","wer")
   NetUse("restime","rst")
   NetUse("jobs","job") 
   NetUse("resource","res")   
   NetUse("folgeart","fol")
   
   NetUse("frepjobs","fjob")

   ? "Downloading manufacturing orders... "

   aData := oFrepple:getManufacturingOrders()

   //Frepple Version 9.13.0 introduces work orders as a separate table
   //Quick fix is to merge these with the manufacturing orders
   aWO := oFrepple:getWorkOrders()
   IF Len(aWO) > 0
      FOR nX := 1 TO Len(aWO)
         AAdd(aData,aWO[nX])
      NEXT
   ENDIF
   oFrepple := NIL

   //gtSetClipboard(HB_JsonEncode(aData))

   ?? "done" 

   ? "Reading data... "
   //gtSetClipboard(ValToPrg(aData))
   IF Len(aData) > 1
      aCSV := {{"FA","Status","Frepple ID","Lieferant","Artikel","Menge alt","Menge neu","Startdatum alt","Startdaum neu","Enddatum alt","Enddatum neu","T„tigkeit"}}

      wer->(dbSetOrder( 1 ))
      
      FOR nX := 1 TO Len(aData)
         nExt := 0  
         
         cJob := ""
         cSupplier := ""
         IF "|" $ aData[nX]["operation"]
            cMatch := SubStr(aData[nX]["operation"],1,AT("|",aData[nX]["operation"])-1)
            nExt := AT("|EXT:",aData[nX]["operation"])
            IF nExt == 0
               cJob := Alltrim(hb_utf8tostr(SubStr(aData[nX]["operation"],AT("|",aData[nX]["operation"])+1)))
            ELSE
               cSupplier :=  hb_utf8tostr(SubStr(aData[nX]["operation"],nExt+5))
            ENDIF
         ELSE
            cMatch := aData[nX]["operation"]
         ENDIF
         cMatch := hb_utf8tostr(cMatch)
         art->(dbSeek(cMatch))
         oArtExtra := art->(ExtraData():New(art->Artikelnr))
         IF Trim(cMatch) == DEBUG_PART
            ? aData[nX]["reference"]
         ENDIF
         //? aData[nX]["reference"],cMatch,cJob,cSupplier,aData[nX]["operation"],aData[nX]["owner"],aData[nX]["owner"]=="FA8820",aData[nX]["reference"]=="FA8820"         
         hRow := {"ID"=>aData[nX]["reference"],"STATUS"=>aData[nX]["status"],"QTY"=>Round(Val(aData[nX]["quantity"]),GetMeDecimals(art->me)),"BADQTY"=>0,"START"=>Frep_StoT(aData[nX]["startdate"]),"END"=>Frep_StoT(aData[nX]["enddate"]),"SUPPLIER"=>cSupplier,"JOBS"=>{},"DELAY"=>aData[nX]["delay"]}         
         IF AT("QS",cJob) == 1 
            IF Trim(cMatch) == DEBUG_PART
               ?? " QS - ignored"
            ENDIF                                    
             //ignore QS   
         ELSEIF hRow["STATUS"] == "closed" //closed orders are not imported
            IF Trim(cMatch) == DEBUG_PART
               ?? " closed"
            ENDIF                        
         ELSEIF ! Empty(cJob) .AND. ! Empty(aData[nX]["owner"]) //internal (has a job) and not routing operation
            IF Trim(cMatch) == DEBUG_PART
               ?? " looking for order..."
            ENDIF

            //scan for owner 
            nAufno := 0   
            nOrder := 0             
            IF AT("FA",aData[nX]["owner"]) == 1
               nAufno := Val(SubStr(aData[nX]["owner"],3))
               IF ! HHasKey(hOrders,nAufno)
                  nAufno := 0                     
               ENDIF
               IF Trim(cMatch) == DEBUG_PART
                  ?? nAufno
               ENDIF
      
            ELSEIF HHasKey(hItems,cMatch)
               nOrder := Ascan(hItems[cMatch],{|x| Trim(x["ID"]) == Trim(aData[nX]["owner"]) })
            ENDIF   

            IF cJob != "DUMMY" //do not import DUMMY operations as jobs
               IF Len(aData[nX]["resources"]) == 0 //No resource planed, e.g. it is completed or the task does not require a resource
                  Aadd(aData[nX]["resources"],{"resource"=>""}) //add a blank record, which  is used in the for loop below
               ENDIF
                                       
               FOR nY := 1 TO Len(aData[nX]["resources"])
                  //? hRow["ID"]
                  aJob := {"ID"=>hRow["ID"],"START"=>hRow["START"],"END"=>hRow["END"],"JOB"=>cJob,"RESOURCE"=>aData[nX]["resources"][nY]["resource"],"STATUS"=>aData[nX]["status"]}
                  IF nAufno != 0
                     Aadd(hOrders[nAufno]["JOBS"],aJob)
                  ELSEIF nOrder != 0
                     Aadd(hItems[cMatch][nOrder]["JOBS"],aJob)
                  ELSE
                     IF ! HHasKey(hJobs,aData[nX]["owner"])
                        hJobs[aData[nX]["owner"]] := {}
                     ENDIF
                     Aadd(hJobs[aData[nX]["owner"]],aJob)                  
                  ENDIF
               NEXT
            ENDIF

            FOR nY := 1 TO Len(aData[nX]["materials"]) //look through the BOM to find the output position
               IF StrTran(aData[nX]["materials"][nY]["item"],"_UNCHECKED","") == Trim(cMatch)                     
                  IF nAufno != 0
                     hOrders[nAufno]["BADQTY"] := Round(hOrders[nAufno]["QTY"]-Val(aData[nX]["materials"][nY]["quantity"]),GetMeDecimals(art->me))                        
                  ELSEIF nOrder != 0
                     hItems[cMatch][nOrder]["BADQTY"] := Round(hItems[cMatch][nOrder]["QTY"]-Val(aData[nX]["materials"][nY]["quantity"]),GetMeDecimals(art->me))
                  ELSE
                     hRealQty[aData[nX]["owner"]] := Val(aData[nX]["materials"][nY]["quantity"])                        
                  ENDIF
               ENDIF  
            NEXT               
         ELSE
            IF HHasKey(hJobs,aData[nX]["reference"])
               hRow["JOBS"] := AClone(hJobs[aData[nX]["reference"]])
               HDel(hJobs,aData[nX]["reference"]) // := {}
            ENDIF
            IF aData[nX]["reference"] $ hRealQty               
               hRow["BADQTY"] := Round(hRow["QTY"]-hRealQty[aData[nX]["reference"]],GetMeDecimals(art->me))
               HDel(hRealQty,aData[nX]["reference"])
            ENDIF

            IF nExt == 0 .OR. oArtExtra:Frep_Ext //internal order or part is marked to import Supplier orders too
               IF AT("FA",aData[nX]["reference"]) == 1 //This is a existing order, we check the dates and move accordingly                  
                  nAufno := Val(SubStr(aData[nX]["reference"],3))               
                  IF ! nAufno $ hOrders
                     hOrders[nAufno] := hRow
                  ENDIF
                  wer->(dbSeek( Str(nAufno,6) ))
                  IF ! HHasKey(hItems,Trim(wer->Matchcode))
                     hItems[cMatch] := {}
                  ENDIF               
               ELSE //this is a newly proposed order    
                  IF Trim(cMatch) == DEBUG_PART
                     ?? " proposed"
                  ENDIF                                    
      
                  IF ! HHasKey(hItems,cMatch)
                     hItems[cMatch] := {}
                  ENDIF
                  Aadd(hItems[cMatch],hRow)
               ENDIF
            ENDIF
         ENDIF
         
      NEXT
      IF Len(hJobs) != 0 .OR. Len(hRealQty) != 0         
         Alert("Error importing data "+Str(Len(hJobs))+Str(Len(hRealQty)))
      ENDIF
   ENDIF

   ?? "done"

   //? "Press any key to continue..."
   //Sinkey(0)

   bAddJobs := {|aJobs,nWA|
      LOCAL nX //,nSt := 1
      job->(dbSetOrder( 2 ))
      res->(dbSetOrder( 2 ))

      IF ! Empty(nWA)
         rst->(dbSetOrder( 1 ))
         rst->(dbSeek( "WA "+Str(wer->Aufno,6) ))  

         //set all existing entries to no resource, so we know which ones have been set       
         DO WHILE Trim(rst->Type) == "WA" .AND. rst->No == wer->Aufno               
            rst->(Rec_Lock(0))
            rst->Resource := -1
            rst->(dbUnLock())                  
            rst->(dbSkip())
         ENDDO
         
      ENDIF

      rst->(dbSetOrder( 6 ))

      FOR nX := 1 TO Len(aJobs)
         hJob := aJobs[nX]
         job->(dbSeek( hJob:Job ))          
         IF hJob:Resource != ""
            res->(dbSeek( hJob:Resource ))  
         ENDIF
         IF ! Empty(nWA) .AND. (rst->(dbSeek( "WA "+Str(nWA,6)+Str(job->Nummer,6)+Str(-1,6) )) .OR. rst->(dbSeek( "WA "+Str(nWA,6)+Str(0,6) )))
            Aadd(aCSV,{nWA,"berschreiben",,,,,,StoT(rst->Start),hJob["START"],Stot(rst->End),hJob["END"],hJob:Job,job->Nummer,hJob:Resource})
            
               rst->(Rec_Lock(0))
               IF hJob:Resource == ""
                  rst->Resource := 0
               ELSE
                  rst->Resource := res->Id                  
               ENDIF
               rst->Start    := TtoS(hJob["START"])
               rst->End      := TtoS(hJob["END"])               
               rst->Complete := hJob["STATUS"] == "completed"               
               rst->(dbUnLock())

               IF fjob->(dbSeek( Str(rst->ID,12) ))
                  fjob->(Rec_Lock(0))
               ELSE
                  fjob->(Add_Rec())
                  fjob->RestimeId := rst->ID   
               ENDIF
               fjob->FreppleID := hb_utf8tostr(hJob["ID"])               
               fjob->(dbUnLock())
            
         ELSEIF ! Empty(nWA)
            Aadd(aCSV,{nWA,"neu",,,,,,,hJob["START"],,hJob["END"],hJob:Job,job->Nummer,hJob:Resource})
            
               
               oRec := rst->(Record():New(.T.))
               oRec:SetId("ID",2)                  
               oRec:Job := job->Nummer
               oRec:No  := nWA
               IF hJob:Resource == ""
                  oRec:Resource := 0
               ELSE
                  oRec:Resource := res->Id
               ENDIF
               oRec:Start := TtoS(hJob["START"])
               oRec:End := TtoS(hJob["END"])
               oRec:Type := "WA"
               oRec:Complete := hJob["STATUS"] == "completed"
               oRec:Save()

               fjob->(Add_Rec())
               fjob->FreppleID := hb_utf8tostr(hJob["ID"])
               fjob->RestimeId := oRec:ID
               fjob->(dbUnLock())
            

         ENDIF
      NEXT
      //prfen ob jobs vorhanden sind die nicht mehr durchgefhrt werden
      //und gleichzeitig start und enddaten des Auftrags ermitteln
      IF ! Empty(nWA)
         rst->(dbSeek( "WA "+Str(wer->Aufno,6) ))
         job->(dbSetOrder( 1 ))
         res->(dbSetOrder( 1 ))
         dStart := StoT("")
         dEnd := StoT("")
         DO WHILE Trim(rst->Type) == "WA" .AND. rst->No == wer->Aufno
            job->(dbSeek( Str(rst->Job,6) ))
            IF rst->Resource > 0
               res->(dbSeek( Str(rst->Resource,6) ))
            ELSEIF rst->Resource == -1
            //IF AScan(aJobs,{|x| x:Job == Trim(job->Name) .AND. x:Resource == IF(rst->Resource==0,"",Trim(res->Name)) }) == 0
               Aadd(aCSV,{nWA,"l”schen",,,,,,Stot(rst->Start),,Stot(rst->End),,job->Name,rst->Job,Trim(res->Name)})
               
               IF fjob->(dbSeek( Str(rst->ID,12)))
                  fjob->(Rec_Lock(0))
                  fjob->(dbDelete())
                  fjob->(dbUnLock())
               ENDIF
               rst->(Rec_Lock())
               rst->(dbDelete())
               rst->(dbUnLock())

               
               
            ENDIF
            rst->(dbSkip())
         ENDDO
      ENDIF

      RETURN NIL
   }

   aMatch := hGetKeys(hItems)
   ASort(aMatch)

   //FOR EACH aData IN hItems
   /*FOR nD := 1 TO Len(hItems)   
      cMatch := HGetKeyAt(hItems,nD)      
      aData  := HGetValueAt(hItems,nD)*/
   FOR nD := 1 TO Len(aMatch)

      cMatch := aMatch[nD]

      IF Trim(cMatch) == DEBUG_PART
         ? DEBUG_PART
      ENDIF                                    


      aData := hItems[cMatch]

      //aData:__enumKey()
      ASort(aData,,,{|x,y|x:Start < y:Start })
      //? cMatch
      art->(dbSetOrder( 1 ))
      art->(dbSeek( cMatch ))

      aKwQty := GetKWQty(art->Artikelnr)        

      wer->(dbsetOrder( 2 ))
      Select("wer")
      SET FILTER TO wer->Status <= 3 .AND. wer->Qty-wer->PlanBad > 0 .AND. Right(Str(wer->TerminFrue,4),2) != "99"
   
      wer->(dbSeek( Str(art->Artikelnr,6) ))
     
      nX := 0
      aList := {}

      nWeek := CWeek(Date())  
      
      DO WHILE wer->Artno == art->Artikelnr .AND. ! wer->(EOF())         
         IF Trim(cMatch) == DEBUG_PART
            ?  wer->Aufno
         ENDIF
   
         IF wer->Aufno $ hOrders //.AND. hOrders[wer->Aufno]:Qty == 0
            IF Trim(cMatch) == DEBUG_PART
               ?? "found"
            ENDIF
            oExtra := wer->(ExtraData():New(wer->Aufno))
            IF (wer->Status >= 1); // .AND. hOrders[wer->Aufno]:Status == "confirmed");
               .OR. (wer->Status == 0) // .AND. Trim(oExtra:FreppleSta) == hOrders[wer->Aufno]:Status)

               //this is an existing order which was exported to frepple, here we just move the dates and tasks
               IF wer->StartDate  != StoD(TtoS(hOrders[wer->Aufno]:Start)) ;
                  .OR. wer->EndDate  != StoD(TtoS(hOrders[wer->Aufno]:End));
                  .OR. wer->PlanBad != hOrders[wer->Aufno]:BadQty;
                  .OR. (/*Trim(oExtra:FreppleSta) == "approved" .AND.*/ wer->Status == 0 .AND. wer->Qty != hOrders[wer->Aufno]:Qty) 

                  IF hOrders[wer->Aufno]:Qty == 0 //frepple would like to delete this order
                     /*IF wer->Status == 0
                        dOldStart := IF(Empty(wer->Liefma),wer->Startdate,CalWD(wer->Termin))
                        dOldEnd := IF(Empty(wer->Liefma),wer->Enddate,CalWD(wer->End))

                        aRow := Array(9)
                        AFill(aRow,"")
                        aRow[1] := wer->Aufno         
                        aRow[6] := .F.
                        aRow[9] := "l”schen"               
                        aRow[2] := LTrim(Transform(wer->Qty,Me(art->Me)))
                        aRow[3] := LTrim(Transform(wer->BadQty,Me(art->Me)))
                        aRow[4] := Dtoc(dOldStart)
                        aRow[5] := DtoC(dOldEnd)
                        Aadd(aList,aRow)
                     ELSE*/
                        Aadd(aCSV,{wer->Aufno,"bestehend","FEHLER",hOrders[wer->Aufno]:Status,wer->Status,oExtra:FreppleSta})
                        Tr_MsgBox({"FA "+LtrIM(str(wer->Aufno))+" hat keine Menge"})
                     //ENDIF
                  ELSE
   
                     Eval(bAddJobs,hOrders[wer->Aufno]:Jobs,wer->Aufno)

                     nOrder := wer->(IndexOrd())

                     oWerk := WA():New()
                     oWerk:Load(wer->Aufno)

                     
                     oWerk:StartDate  := StoD(TtoS(hOrders[wer->Aufno]:Start))
                     oWerk:EndDate    := StoD(TtoS(hOrders[wer->Aufno]:End))

                     //DO NOT CHANGE QUANTITY ON CONFIRMED ORDERS, the quantity is always the remaining quantity
                     IF /*Trim(oExtra:FreppleSta) == "approved" .AND.*/ wer->Status == 0 //only on non confirmed orders change quantities
                        oWerk:Qty := hOrders[wer->Aufno]:Qty
                     ENDIF   
                     oWerk:PlanBad := hOrders[wer->Aufno]:BadQty
                     oWerk:Save()
                  ENDIF

                  wer->(dbSetOrder(nOrder))
                     
               ELSE

                  Eval(bAddJobs,hOrders[wer->Aufno]:Jobs,wer->Aufno)
               ENDIF
            ELSE
               Aadd(aCSV,{wer->Aufno,"bestehend","FEHLER",hOrders[wer->Aufno]:Status,wer->Status,oExtra:FreppleSta})
               aError := {"FA "+LtrIM(str(wer->Aufno))+" kann nicht ge„ndert werden"}

               IF wer->Status >= 1 .AND. hOrders[wer->Aufno]:Status != "confirmed"
                  Aadd(aError,"Status in Frepple ("+hOrders[wer->Aufno]:Status+") weicht von Trader ab (in Produktion)")
               ELSEIF (wer->Status == 0 .AND. Trim(oExtra:FreppleSta) == "confirmed")
                  Aadd(aError,"Status in Frepple ("+hOrders[wer->Aufno]:Status+") weicht von Trader ab ("+Trim(oExtra:FreppleSta)+")")
               ELSEIF wer->Status != 0
                  Aadd(aError,"Da stimmt was nicht")
               ELSE
                  Aadd(aError,"Keine Ahnung warum")
               ENDIF               
               Aadd(aError,"Frepple ID: "+hOrders[wer->Aufno]:ID)
               Tr_MsgBox(aError)
            ENDIF
         ELSEIF wer->Status == 0            //„ndern
            aRow := Array(9)
            AFill(aRow,"")   

            aRow[1] := wer->Aufno         
            aRow[6] := .T.           //bernehmen

            dOldStart := IF(Empty(wer->Liefma),wer->Startdate,CalWD(wer->Termin))
            dOldEnd := IF(Empty(wer->Liefma),wer->Enddate,CalWD(wer->End))

            nX++
            IF nX <= Len(aData) //we can change an existing order to fit               
               aRow[9] := "„ndern"
               aRow[7] := aData[nX]
               lChange := .F.                              
               IF Empty(wer->Liefma) .AND. dOldStart != StoD(TtoS(aData[nX]:Start));
                   .OR. ! Empty(wer->Liefma) .AND. wer->Termin != Val(CalWeek(aData[nX]:Start))
                  lChange := .T.                  
                  aRow[4] := DtoC(dOldStart)+"->"+Dtoc(aData[nX]:Start)
               ELSE
                  aRow[4] := Dtoc(aData[nX]:Start) 
               ENDIF
               IF Empty(wer->Liefma) .AND. dOldEnd != aData[nX]:End;
                   .OR. ! Empty(wer->Liefma) .AND. wer->End != Val(CalWeek(aData[nX]:End))
                  aRow[5] := Dtoc(dOldEnd)+"->"+DtoC(aData[nX]:End)
               ELSE
                  aRow[5] := DtoC(aData[nX]:End)
               ENDIF
               aRow[2] := LTrim(Transform(wer->Qty,Me(art->Me)))
               IF wer->Qty != aData[nX]:Qty
                  lChange := .T.                  
                  aRow[2] += "->"+LTrim(Transform(aData[nX]:Qty,Me(art->Me)))
               ENDIF
               aRow[3] := LTrim(Transform(wer->PlanBad,Me(art->Me)))
               IF wer->PlanBad != aData[nX]:BadQty                  
                  aRow[3] += "->"+AlLTrim(Transform(aData[nX]:BadQty,Me(art->Me)))
               ENDIF
               
               IF lChange
                  IF Trim(cMatch) == DEBUG_PART
                     ?? "changing ",aData[nX]:ID
                  ENDIF

                  Aadd(aList,aRow)
                  Aadd(aCSV,{wer->Aufno,"berschreiben",aData[nX]:Id,aData[nX]:Supplier,Trim(art->Matchcode),wer->Qty,aData[nX]:Qty,dOldStart,aData[nX]:Start,dOldEnd,aData[nX]:End})                  
                  
                  nKW := AScan(aKwQty,{|x| x[1] == IF(wer->End>=nWeek,wer->End,0) })
                  IF nKW == 0
                     Alert("Woche nicht gefunden "+art->Matchcode+" "+Str(wer->End,4)+" FA "+Str(wer->Aufno))
                  ENDIF
                  aKWQty[nKW,5] -= wer->Qty-wer->PlanBad-wer->GelQty
                  
                  AEval(aKWQty,{|x| x[6] -= wer->Qty-wer->PlanBad-wer->GelQty },nKW)                  
               ELSE //no change, so just make sure the jobs are in-sync
                  IF Trim(cMatch) == DEBUG_PART
                     ?? "applying jobs from",aData[nX]:ID
                  ENDIF
      
                  Eval(bAddJobs,aData[nX]:Jobs,wer->Aufno)               
               ENDIF               
            ELSE //dieser Auftrag wird nicht mehr gebraucht und kann gel”scht werden
               aRow[9] := "l”schen"               
               
               aRow[2] := LTrim(Transform(wer->Qty,Me(art->Me)))
               aRow[3] := LTrim(Transform(wer->BadQty,Me(art->Me)))
               aRow[4] := Dtoc(dOldStart)
               aRow[5] := DtoC(dOldEnd)
               Aadd(aList,aRow)
               //Aadd(aCSV,{wer->Aufno,"l”schen",,,Trim(art->Matchcode),wer->Qty})           
               nKW := AScan(aKwQty,{|x| x[1] == wer->End })
               IF nKW == 0
                  Alert("Woche nicht gefunden "+art->Matchcode+" "+Str(wer->End)+" FA "+LTrim(Str(wer->Aufno)))
               ENDIF
               aKWQty[nKW,5] -= wer->Qty-wer->PlanBad-wer->GelQty
               AEval(aKWQty,{|x| x[6] -= wer->Qty-wer->PlanBad-wer->GelQty},nKW) 
               
            ENDIF
         ELSE
            IF Trim(cMatch) == DEBUG_PART
               ?? "ignoring wrong status",wer->Status
            ENDIF

         ENDIF
         wer->(dbSkip())
      ENDDO      

      wer->(dbClearFilter())

      IF Trim(cMatch) == "KS26206.04"
         //? ValToPRg(aData)
         //SInkey(0)
      ENDIF

      
      nSt := nX+1
      FOR nX := nSt TO Len(aData)
         aRow := Array(9)
         AFill(aRow,"")
         aRow[1] := 0
         aRow[9] := "neu"  
         aRow[2] := LTrim(Transform(aData[nX]:Qty,Me(art->Me)))
         aRow[3] := LTrim(Transform(aData[nX]:BadQty,Me(art->Me)))
         aRow[4] := Dtoc(aData[nX]:Start)
         aRow[5] := DtoC(aData[nX]:End)
         aRow[6] := .T.  //bernehmen?
         aRow[7] := aData[nX]         
         Aadd(aList,aRow)
      NEXT

      IF Len(aList) > 0
         
         SetColor(c_four)
         @ 05,00 CLEAR TO MaxRow(),MaxCol()
         @ 05,00 TO MaxRow(),MaxCol()
         @ 05,03 SAY "[ Artikel: "+cMatch+ "]"
         @ MaxRow()-9,01 SAY Replicate(Chr(196),MaxCol()-2)
         @ MaxRow()-9,03 SAY "[ Bedarf ]"

         FOR nX := 1 TO Len(aKWQty)
            IF aKWQty[nX,6] < 0  .AND. aKWQty[nX,2]+aKwQty[nX,4] > 0
               ? 
               @ Row(),03 SAY DtoC(CalWD(aKWQty[nX,1],4)+4)+" "+TransForm(Min(aKWQty[nX,2]+aKwQty[nX,4],aKwQty[nX,6]*-1),Me(art->Me))
            ENDIF
            IF Row() == MaxRow()-1
               EXIT
            ENDIF
         NEXT         

         @ MaxRow(),03 SAY "[ >ENTER< - ja/nein | >TAB< - Speichern | >SHIFT-TAB< - zurck | ESC< - abbrechen ]"
         oBrowse := TABrowse():New(06,01,MaxRow()-10,MaxCol()-1)
         oBrowse:NewColumn("",{|| IF(oBrowse:CurrentDataRow()[6],"JA  ","nein") })
         oBrowse:NewColumn("Art",{|| Pad(oBrowse:CurrentDataRow()[9],7) })
         oBrowse:NewColumn("Auftrag",{|| 
            IF oBrowse:CurrentDataRow()[1] != 0
               RETURN Str(oBrowse:CurrentDataRow()[1],6)
            ENDIF
            RETURN ""
         })
         oBrowse:NewColumn("Menge",{|| PadL(oBrowse:CurrentDataRow()[2],10) })
         oBrowse:NewColumn("Ausschuá",{|| oBrowse:CurrentDataRow()[3] })
         oBrowse:NewColumn("Start",{|| oBrowse:CurrentDataRow()[4] })
         oBrowse:NewColumn("Ende",{|| oBrowse:CurrentDataRow()[5] })
         oBrowse:NewColumn("Frepple ID",{|| 
            LOCAL aData := oBrowse:CurrentDataRow()
            IF Len(aData) >= 7.AND. ValType(aData[7]) == "H"
               RETURN aData[7]["ID"]
            ENDIF
            RETURN Space(20)
         })
         oBrowse:NewColumn("",{|| 
            LOCAL aData := oBrowse:CurrentDataRow()
            LOCAL cText := ""
            IF Len(aData) >= 7.AND. ValType(aData[7]) == "H"
               IF HHasKey(aData[7],"SUPPLIER")               
                  IF ! Empty(cText)
                     cText += " "
                  ENDIF
                  cText += aData[7]["SUPPLIER"] 
               ENDIF
               RETURN cText
            ENDIF
            RETURN NIL
         })
         
         oBrowse:AddKey(K_TAB,{|| .F. })
         oBrowse:AddKey(K_SH_TAB,{|| .F. })
         oBrowse:AddKey(K_LEFT,{|| oBrowse:Left() })
         oBrowse:AddKey(K_RIGHT,{|| oBrowse:Right() })
         oBrowse:AddKey(K_ENTER,{|| oBrowse:CurrentDataRow()[6] := ! oBrowse:CurrentDataRow()[6],.T. })
         oBrowse:AddKey(K_ESC,{|| .F. })
         oBrowse:OneColumn := .T.
         oBrowse:lBox := .F.
         oBrowse:aData := aList
         oBrowse:EventLoop()         
         SetColor(c_one)
         IF LastKey() == K_ESC
            EXIT
         ENDIF
         IF LastKey() == K_SH_TAB 
            IF nD > 1
               nD -= 2 //go to previous record, need to remove two as one is added by the loop again
            ELSE
               nD -= 1 //stay on this record
            ENDIF
            LOOP
         ENDIF
         FOR nX := 1 TO Len(aList)
            IF aList[nX,6]
               IF Alltrim(aList[nX,9]) == "l”schen"
                  oWerk := WA():New()
                  oWerk:Load(aList[nX,1])
                  oWerk:Delete()  //also deletes the PO if there is one
               ELSE
                  oBes := NIL
                  IF AllTrim(aList[nX,9]) == "neu"
                     art->(dbSetOrder( 1 ))
                     IF ! art->(dbSeek( cMatch ))
                        Alert("Artikel nicht gefunden: "+cMatch)
                        LOOP
                     ENDIF
                     oWerk := WA():New(.T.)
                     oWerk:Date := Date()
                     oWerk:Artno := art->Artikelnr
                     /*Alert(Str(art->Artikelnr))
                     Alert(Str(oWerk:Artno))
                     Alert(oWerk:Artikel:Matchcode)*/
                     IF ! Empty(aList[nX,7]:Supplier)
                        NetUSe("engnr","nr")
                        nBesnr := 0
                        Do While nBesnr == 0 .OR. bes->(dbSeek( Str(nBesnr,6) ))
                           nBesnr := nr->besnr + 1
                  
                           nr->(rec_lock(0))
                           REPLACE nr->besnr WITH nBesnr
                           nr->(dbUnLock())
                        Enddo
                        nr->(dbCloseArea())
                  
                        oBes := BestellungPos():New(.T.)
                        oBes:Besda := Date()
                        oBes:Liefma  := aList[nX,7]:Supplier
                        oBes:Besnr := nBesnr 
                        oBes:Posnr := 1
                        oWerk:Liefma := aList[nX,7]:Supplier
                        oWerk:Liefad := aList[nX,7]:Supplier
                        oWerk:BesPos := 1
                        oWerk:Besnr := nBesnr
                     ENDIF
                  ELSE
                     IF ! LockEntity("WA",aList[nX,1]) 
                        LOOP
                     ENDIF
                     oWerk := WA():New()
                     oWerk:Load(aList[nX,1])
                     bes->(dbSetOrder(1))
                     IF oWerk:Besnr != 0  .AND. bes->(dbSeek( Str(oWerk:besnr,6)+Str(oWerk:bespos,3)))
                        IF ! LockEntity("BES",oWerk:besnr) 
                           LOOP
                        ENDIF
                        oBes := BestellungPos():New(.F.)
                        oBes:Load(oWerk:Besnr)
                     ENDIF
                  ENDIF
                  oWerk:StartDate := StoD(TtoS(aList[nX,7]:Start))
                  oWerk:EndDate := StoD(TtoS(aList[nX,7]:End))
                  IF oWerk:Status <= 1
                     oWerk:Qty := aList[nX,7]:Qty
                     oWerk:PlanBad := aList[nX,7]:BadQty
                     IF oBes != NIL
                        oBes:Qty := aList[nX,7]:Qty
                     ENDIF
                  ENDIF
                  oWerk:Save()  //this also updates Termin and End

                  IF Alltrim(aList[nX,9]) == "neu"
                     oWerk:CreatePartList()
                  ENDIF                  

                  IF oBes != NIL
                     we->(dbSetOrder(4))
                     IF we->(dbSeek( Str(oWerk:Aufno,6)+Str(-1,4) )) //lohnfertigungsposition finden
                        oBes:Matchcode := we->Matchcode
                     ELSE
                        //Alert("H„? "+Str(oWerk:Aufno,6)+Str(-1,3) )
                     ENDIF
                     oBes:ShipTime := 1
                     oBes:Lterm    := oWerk:End-oBes:ShipTime
                     oBes:Wterm    := oWerk:Termin-oBes:ShipTime
                     oBes:Released := .T.

                     GetBuyPrice(oBes:Liefma,oBes:Artikelnr,oBes:Qty,@oBes:EkPr,@oBes:Pe,.T.)
                     IF oBes:Pe == 0
                        oBes:Pe := 1
                     ENDIF
                     oBes:Save()

                     IF Alltrim(aList[nX,9]) == "neu" .AND. fol->(dbSeek(Str(oBes:Artikelnr,6)))
                        nLastPosnr := 1
                        Do While oBes:Artikelnr == fol->Artikelnr .AND. ! fol->( EOF() )
                           art->(dbSetOrder(2))
                           art->(dbSeek(Str(fol->Folgeart,6)))
                           art->(dbSetOrder(1))

                           If ! art->(Found())                              
                              fol->(dbSkip())
                              LOOP
                           Endif

                           nLastPosnr++

                           bes->(Add_Rec(0))
                           bes->besnr     := nBesnr
                           bes->posnr     := nLastPosnr
                           bes->liefma    := oBes:Liefma
                           bes->besda     := oBes:BesDa
                           bes->matchcode := art->matchcode
                           bes->artikelnr := art->Artikelnr
                           bes->buyer     := oBes:Buyer
                           bes->confirmed := IF(EMPTY(oBes:AbNr),"N","Y")
                           bes->pay       := oBes:Pay
                           bes->abnr      := oBes:AbNr
                           bes->person    := oBes:Person
                           bes->Printed   := .F.
                           bes->beqty    := oBes:Qty*fol->Faktor
                           bes->wterm     := oBes:WTerm
                           bes->LTerm := oBes:LTerm
                           bes->Mahnen  := .F.
                           bes->Pe := 1
                           bes->money     := oBes:Money
                           bes->rate      := currate(oBes:Money,"E")
                           bes->FolgeTo    := oBes:Posnr
                           bes->FolgeFakto  := fol->Faktor
                           bes->ShipTime  := oBes:Shiptime
                           bes->Released  := .T.
                           bes->( dbUnlock() )

                           fol->(dbSkip())
                        Enddo
                     ENDIF
                  ENDIF

                  //do not set the status to approved, otherwise Frepple cannot plan on the next import
                  /*oExtra := wer->(ExtraData():New(oWerk:Aufno))
                  oExtra:FreppleSta := "approved"
                  oExtra:Save()*/
                  IF Alltrim(aList[nX,9]) != "neu"
                     UnLockEntity("WA",aList[nX,1])
                     IF oBes != NIL
                        UnLockEntity("BES",oBes:besnr)
                     ENDIF
                  ENDIF
                  Eval(bAddJobs,aList[nX,7]:Jobs,oWerk:Aufno)
               ENDIF
            ENDIF
         NEXT
         FOR nX := 1 TO Len(aList)
            IF aList[nX,6]
               HB_ADel(aList,nX,.T.)
               nX--
            ENDIF
         NEXT
      ENDIF
   NEXT

   cFileName := PatH("import\frepple\import-"+TtoS(DateTime())+".csv")
   IF Tr_getini(28) == 9 .AND. Tr_MsgBox("Importprotokoll speichern?",,{"Ja","Nein"}) == 1
      SaveAsCSV(cFileName,aCSV)
      WAPI_ShellExecute(,"open",cFileName)
   ENDIF

   //Sinkey(0)
   IF nColCount < 186
      SetMode(nRowCount,nColCount)
   ENDIF
   UnLockEntity("PPLIM",0)
RETURN

   
   #include 'x:\run\frepple_curl.prg'