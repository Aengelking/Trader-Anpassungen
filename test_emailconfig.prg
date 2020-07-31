//SendMail(aTo,cSubject,cMessage,aAttachement,lIntern,nPriority,lHtml)

CLS

//update ini
Ini_DriveMem()

aList := {;
   "SO-NOSTOCK",;
   "SO-NOSTOCK-SEVERE",;
   "SO-MINSTOCK",;
   "SO-READY",;
   "SO-NOTPAID",;
   "SO-JIT-NODEL",;
   "SO-PART-READY",;
   "SO-MOVED",;
   "PROD-NOSTOCK",;
   "PROD-READY",;
   "PROD-SPLIT",;
   "PROD-NEAR",;
   "PROD-OVERDUE",;
   "SAMPLE-READY",;
   "SAMPLE-NOSTOCK",;
   "STOCK-MIN",;
   "STOCK-MAX";
}
FOR nX := 1 TO Len(aList)
   ? aList[nX]
   SendMail(GetConfigEmail(aList[nX]),aList[nX],"HELLO WOLRD")
NEXT

Alert("completed")