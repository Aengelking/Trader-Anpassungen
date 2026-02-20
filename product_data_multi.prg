/**
 * Run product data export for all configured channels
 */

#include "x:\run\product_data\channel_config.ch"

PROCEDURE ProductData_AllChannels(lPrices, lUploadOnly)
	LOCAL aChannels, nX

	Default(@lPrices, .T.)
	Default(@lUploadOnly, .F.)

	IF ! LoadAllChannelConfigs()
		Alert("Failed to load channel configurations")
		RETURN
	ENDIF

	aChannels := GetAvailableChannels()
	FOR nX := 1 TO Len(aChannels)
		ProductDataXML(lPrices, lUploadOnly, aChannels[nX])
	NEXT

RETURN
