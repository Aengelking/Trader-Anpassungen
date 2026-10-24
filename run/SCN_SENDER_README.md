# SCN SENDER - Specification Change Notice Sender

## Overview

The SCN (Specification Change Notice) Sender is a new program designed to send SCNs for multiple drawings simultaneously. It's based on the existing `_SENDSCN` function in `trd_nr_zeich.prg` but provides a user-friendly interface for batch processing multiple SCNs.

## Features

- **Batch Processing**: Send SCNs for multiple articles at once
- **PDF Generation**: Automatically creates PDF documents from OpenOffice templates
- **Email Integration**: Uses the existing `SendMail` and `EmailSendInterface` functions
- **User Confirmation**: PDFs are created first, then user confirms before sending
- **Grouped Sending**: SCNs for the same supplier contact are sent together

## Files Created

1. **scn_sender.prg** - Main SCN sender program
2. **scn_test.prg** - Test program to verify functionality

## Prerequisites

### System Requirements
- OpenOffice or LibreOffice installed and accessible via COM
- Access to the trader database tables:
  - `artikel` (articles)
  - `engkund` (customers/suppliers) 
  - `contacts` (contact persons)
- Template file: `Y:\Dokumente und Einstellungen\All Users\Dokumente\Vorlagen\QM\fb123_Spezifikations„nderungsmitteilung_1.5.ott`
- SCN output directory: `Y:\Dokumente und Einstellungen\All Users\Dokumente\QS\SCN\`

### Existing Functions Required
The program uses these existing functions from the trader system:
- `SendMail()` - Email sending function
- `OpenOOWriterTemplate()` - OpenOffice template handling
- `OOProperty()` - OpenOffice property creation
- `GetContact()` - Contact information retrieval
- `FindAd()` - Address/customer lookup
- `Tr_MsgBox()` - Message box display

## Usage Instructions

### Starting the Program

```harbour
// Call from main menu or directly
SCN_SENDER()
```

Or run the test program first:
```harbour
Test_SCN_Sender()
```

### Main Interface

The main interface shows a browse window with the following columns:
- **Artikel** (Article)
- **Zeichnung** (Drawing)
- **Rev** (Revision)  
- **Lieferant** (Supplier)
- **Status** (Status)

### Function Keys

- **F2** - Add new article to SCN list
- **F3** - Edit selected SCN item
- **F4** - Remove selected item
- **F5** - Create PDFs for all items
- **F6** - Send all SCNs via email
- **ESC** - Exit program

### Workflow

1. **Add Articles** (F2)
   - Enter article matchcode
   - System finds article and shows description
   - Select supplier and contact person
   - Set production stop and BOM change flags

2. **Create PDFs** (F5)
   - System creates PDF for each article using OpenOffice template
   - PDFs are saved to the SCN directory
   - Status is updated to show creation success/failure

3. **Send SCNs** (F6)
   - System groups SCNs by supplier contact
   - Sends email with all relevant PDFs attached
   - One email per contact with multiple SCNs if applicable

## Template Fields

The OpenOffice template supports these fields:
- `Lieferant` - Supplier name
- `ProductionstopYes/No` - Production stop checkboxes
- `BOMYes/No` - BOM change checkboxes  
- `Artikel` - Article matchcode
- `Zeichnungsnummer` - Drawing number
- `Zeichnungsrevision` - Drawing revision

## File Naming Convention

PDF files are created with this naming pattern:
```
SCN_{ArticleMatchcode}_{DrawingNumber}[-{Revision}]_{YYYYMMDD}_{HHMMSS}.pdf
```

Example: `SCN_ABC_123_456-A_20241012_143022.pdf`

## Error Handling

The program includes error handling for:
- Missing template files
- OpenOffice connection issues
- Invalid article data
- Missing contact email addresses
- PDF generation failures
- Email sending errors

## Integration

### Menu Integration

Add to your main menu system:
```harbour
// In your menu definition
AADD(aMenuItems, {"SCN Sender", "SCN_SENDER()"})
```

### Hotkey Integration

```harbour
// Add hotkey for quick access
SetKey(K_ALT_S, {|| SCN_SENDER() })
```

## Testing

Use the test program to verify:
1. OpenOffice template access
2. Database connectivity
3. PDF generation prerequisites
4. Directory permissions

```harbour
Test_SCN_Sender()
```

## Troubleshooting

### Common Issues

1. **Template not found**
   - Verify template path exists
   - Check file permissions

2. **OpenOffice connection failure**
   - Ensure OpenOffice/LibreOffice is installed
   - Try starting OpenOffice manually first

3. **PDF generation fails**
   - Check SCN directory exists and is writable
   - Verify template contains required fields

4. **Email sending fails**
   - Check contact has valid email address
   - Verify SMTP configuration

### Debug Information

The program shows status messages during operation:
- PDF creation progress
- Email sending status
- Error details for troubleshooting

## Customization

### Template Modifications

To modify the template fields, update the `hTemplateData` hash in `SCN_CreateSinglePDF()`:

```harbour
hTemplateData := {=>}
hTemplateData["Lieferant"] := hItem["LIEFERANT"]
hTemplateData["NewField"] := "New Value"  // Add custom fields
```

### Email Content

Modify email subject and message in `SCN_SendEmailGroup()`:

```harbour
cSubject := "Custom subject line"
cMessage := "Custom message content"
```

### Directory Paths

Update the path constants at the top of the file:

```harbour
#define PATH_SCN "Your\Custom\Path\"
```

## Future Enhancements

Possible improvements:
- Save/load SCN lists for reuse
- Email template integration
- Multilingual support
- Audit trail logging
- Integration with drawing management system

## Support

For issues or questions:
1. Check the test program output
2. Verify all prerequisites are met
3. Check error messages for specific issues
4. Consult existing SCN functions in `trd_nr_zeich.prg`
