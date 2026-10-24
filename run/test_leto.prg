USE ARTIKEL VIA "DBFCDX" SHARED ALIAS ART
USE "//192.168.2.200:2812/ARTIKEL" VIA "LETO" ALIAS S_ART
s_art->(dbSetIndex("NTX/Artikel.cdx"))
s_art->(dbSetFilter({||s_art->Manufactur==9}))
/*IF LETO_ISFLTOPTIM()
   Alert("Filter is optimised")
ENDIF*/
FOR nX := 1 TO 100
   ? s_art->Matchcode
   s_art->(dbSkip())
NEXT

Inkey(0,128)