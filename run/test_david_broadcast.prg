#include 'y:\harbour\trader\source\include\david.ch'

PROC TEST_DAVID_BROADCAST
   LOCAL oApp := CreateObject("DVOBJAPILib.DvISEAPI")
   LOCAL oAccount := oApp:Logon("", "", "", "", "", "AUTH")
   LOCAL oResources := oAccount:Resources
   LOCAL oBroadcasts := oResources:BroadcastLists 
   LOCAL nX
   
   CLS
   ? "Path: ", oBroadcasts:Location
   ? "Total: ", oBroadcasts:Count
   For nX := 0 To oBroadcasts:Count-1
      ? "Name: ", oBroadcasts:Item(nX):Description
      ? "File: ", oBroadcasts:Item(nX):Name  
        
   Next
Inkey(0,128)