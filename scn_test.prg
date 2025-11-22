#include 'trader.ch'
#include 'inkey.ch'

#define PATH_SCN "Y:\Dokumente und Einstellungen\All Users\Dokumente\QS\SCN\"

/******************************************************************************
 * SCN SENDER - TEST PROGRAM
 * 
 * Simple test program to verify the SCN sender functionality
 ******************************************************************************/

FUNCTION Test_SCN_Sender()
    LOCAL nKey
    
    // Make sure we have database access
    NetUse("artikel","art")
    NetUse("engkund","ku") 
    NetUse("contacts","conts")
    NetUse("nr_zeich","nrz")
    
    CLS
    ? "SCN SENDER TEST"
    ? "==============="
    ? ""
    ? "This test will verify the SCN sender functionality."
    ? ""
    ? "Available test functions:"
    ? "1. Check OpenOffice Template Access"
    ? "2. Check Database Tables"
    ? "3. Test PDF Creation (without actually creating)"
    ? "4. Launch SCN Sender Interface"
    ? ""
    ? "Press 1-4 to run a test, or ESC to exit"
    
    DO WHILE .T.
        nKey := Inkey(0)
        
        SWITCH nKey
            CASE Asc("1")
                Test_OO_Template()
                EXIT
            CASE Asc("2") 
                Test_Database_Access()
                EXIT
            CASE Asc("3")
                Test_PDF_Generation()
                EXIT
            CASE Asc("4")
                SCN_Sender_Main()
                EXIT
            CASE 27 // ESC
                RETURN NIL
        END
    ENDDO
    
RETURN NIL

FUNCTION Test_OO_Template()
    LOCAL cTemplateFile := 'Y:\Dokumente und Einstellungen\All Users\Dokumente\Vorlagen\QM\fb123_Spezifikations„nderungsmitteilung_1.5.ott'
    LOCAL oOO
    
    CLS
    ? "Testing OpenOffice Template Access..."
    ? "======================================"
    ? ""
    ? "Template file: " + cTemplateFile
    ? ""
    
    IF File(cTemplateFile)
        ? "? Template file found"
    ELSE
        ? "? Template file NOT found"
        ? "  Please check the template path"
    ENDIF
    
    ? ""
    ? "Attempting to create OpenOffice service manager..."
    
    oOO := CreateObject("com.sun.star.ServiceManager")
    IF oOO != NIL
        ? "? OpenOffice service manager created successfully"
        ? "? OpenOffice is available for PDF generation"
    ELSE
        ? "? Failed to create OpenOffice service manager"
        ? "  Please ensure OpenOffice/LibreOffice is installed"
    ENDIF
    
    ? ""
    ? "Press any key to continue..."
    Inkey(0)
    
RETURN NIL

FUNCTION Test_Database_Access()
    CLS
    ? "Testing Database Access..."
    ? "=========================="
    ? ""
    
    // Test artikel table
    IF Select("art") != 0
        ? "? Artikel table accessible"
        ? "  Records: " + LTrim(Str(art->(LastRec())))
    ELSE
        ? "? Artikel table not accessible"
    ENDIF
    
    // Test engkund table
    IF Select("ku") != 0
        ? "? Engkund table accessible" 
        ? "  Records: " + LTrim(Str(ku->(LastRec())))
    ELSE
        ? "? Engkund table not accessible"
    ENDIF
    
    // Test contacts table
    IF Select("conts") != 0
        ? "? Contacts table accessible"
        ? "  Records: " + LTrim(Str(conts->(LastRec())))
    ELSE
        ? "? Contacts table not accessible"  
    ENDIF
    
    ? ""
    ? "Press any key to continue..."
    Inkey(0)
    
RETURN NIL

FUNCTION Test_PDF_Generation()
    LOCAL cPdfPath := PATH_SCN + "TEST_SCN_" + DToS(Date()) + "_" + StrTran(Time(),":","") + ".pdf"
    
    CLS
    ? "Testing PDF Generation..."
    ? "========================"
    ? ""
    ? "Test PDF path: " + cPdfPath
    ? ""
    
    IF !DirExists(PATH_SCN)
        ? "? SCN directory does not exist: " + PATH_SCN
        ? "  Please create the directory or check the path"
    ELSE
        ? "? SCN directory exists"
    ENDIF
    
    ? ""
    ? "This test only verifies paths and prerequisites."
    ? "Actual PDF generation requires valid article data."
    ? ""
    ? "Press any key to continue..."
    Inkey(0)
    
RETURN NIL

// Helper function to check if directory exists
FUNCTION DirExists(cPath)
    LOCAL aDir := Directory(cPath, "D")
RETURN Len(aDir) > 0
