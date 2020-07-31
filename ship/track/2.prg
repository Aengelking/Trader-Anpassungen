PARAMETERS cID

LOCAL oHttp
LOCAL cUrl
LOCAL hRequest,hData

cUrl := "https://wwwcie.ups.com/rest/Track"
//cUrl := "https://onlinetools.ups.com/rest/Track"

oHttp := TIpClientHttp():new( cUrl )
//oHttp:nConnTimeout := 20000
oHttp:hFields["Content-Type"] := "application/json"

hRequest := {;
   "UPSSecurity" => {;
      "UsernameToken" => {;
         "Username" => "aengelking",;
         "Password" => "P8-Q[Vh=c}";
      },;
      "ServiceAccessToken" => {;
         "AccessLicenseNumber" => "7D25DCE12016C7FE";
      };
   },;
   "TrackRequest" => {;
      "Request" => {;
         "RequestOption" => "15",;
         "TransactionReference" => {;
            "CustomerContext" => "Your Test Case Summary Description";
         };
      },;
      "InquiryNumber" => cID,; //"1Z12345E0205271688",; //"1Z7748876854468437",; //"1Z7748876852029192",;
      "TrackingOption" => "02";
   };
}
cStatus := ""
dDate := Stod("")

IF oHttp:Open()
   oHttp:Post(HB_JsonEncode(hRequest))
   HB_JsonDecode(oHttp:ReadAll(),@hData)
   //? ValToPrg(hdata)
   IF HHasKey(hData,"Fault") //we have an error
      ? hData["Fault"]["detail"]["Errors"]["ErrorDetail"]["PrimaryErrorCode"]["Description"]
   ELSE
      SWITCH hData["TrackResponse"]["Shipment"]["Package"]["Activity"][1]["Status"]["Type"]
         CASE "D"
            cStatus := "DEL"
            EXIT
         CASE "I"
         CASE "P"
            IF hData["TrackResponse"]["Shipment"]["Package"]["Activity"][1]["Status"]["Code"] == "006"
               cStatus := "OFD"
            ELSE
               cStatus := "OTR"
            ENDIF
            EXIT
         CASE "X"
            cStatus := "EXC"
            EXIT
      END
      dDate := StoD(hData["TrackResponse"]["Shipment"]["Package"]["Activity"][1]["Date"])

      cHtml := ""
      //FOR nX := 1 TO Len(hData["TrackResponse"]["Shipment"]["Package"]["Activity"])
      nX := 1
         /*? hData["TrackResponse"]["Shipment"]["Package"]["Activity"][nX]["Status"]["Description"]
         ?? "",hData["TrackResponse"]["Shipment"]["Package"]["Activity"][nX]["Status"]["Type"]
         ?? "",hData["TrackResponse"]["Shipment"]["Package"]["Activity"][nX]["Status"]["Code"]
         ?? "",DtoC(StoD(hData["TrackResponse"]["Shipment"]["Package"]["Activity"][1]["Date"]))
         ?? "",hData["TrackResponse"]["Shipment"]["Package"]["Activity"][nX]["Time"]*/
   /*      IF ! HHasKey(hData["TrackResponse"]["Shipment"]["Package"]["Activity"][nX],"Document")
            cHtml += "<br>NO Doc available"
         ELSE
            cHtml += "<br>"+hData["TrackResponse"]["Shipment"]["Package"]["Activity"][nX]["Document"]["Type"]["Code"] //needs to be 01 for signature
            cHtml += "<br>"+hData["TrackResponse"]["Shipment"]["Package"]["Activity"][nX]["Document"]["Format"]["Code"] //01=gif
         ENDIF*/
//      NEXT
   ENDIF
//   cHtml := ValToPrg(hData)
//   cHtml += ValType(oHttp:nReplyCode)
ELSE
   cHtml := "ERROR OPENING URL"
ENDIF

oHttp:Close()

RETURN {cStatus,dDate}

/*Wvt_DrawImage( MaxRow()-1,01,MaxRow(),02, "X:\run\LOGO_S.gif" )
@ MaxRow()-1,04 SAY "UPS, the UPS brand mark, and the Color Brown are trademarks of United Parcel Service"
@ MaxRow(),04 SAY "of America, Inc. All Rights Reserved."*/
