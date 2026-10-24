

FUNC TEST_UUID_LINK
	LOCAL cBlowFish := hb_blowfishKey( "js2RGC7sX9td4EH2kTABZf8XDdhkGdtzcw27DcFzsHiRDKUAbr" )
   LOCA cUUID := win_UuidCreateString()
	LOCAL cEncrypted := hb_blowfishEncrypt( cBlowFish, cUUID )

   ? cUUID
   ? cEncrypted
   Sinkey(0)