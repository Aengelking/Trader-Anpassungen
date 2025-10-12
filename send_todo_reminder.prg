#define CRLF Chr(13)+CHr(10)

// Function to send todos for all users (batch processing)
PROC SEND_ALL_USER_TODOS()  
   NetUse("buyer","buy")
   buy->(dbGoTop())
   
   DO WHILE !buy->(EOF())
      IF !Empty(buy->Email) .AND. buy->Aktive // Assuming there's an Active field
         SEND_USER_TODO_EMAIL(buy->(RecNo()))
      ENDIF
      buy->(dbSkip())
   ENDDO
   
   //Tr_MsgBox("Alle Benutzer-E-Mails wurden verarbeitet")
RETURN


PROC SEND_USER_TODO_EMAIL(nUserId)
   LOCAL aAllTodos := {}
   LOCAL hRecordTypes
   LOCAL cEmailBody := ""
   LOCAL cUserEmail
   LOCAL cUserName
   LOCAL i

   // Get user information
   NetUse("buyer","buy")
   buy->(dbGoTo(nUserId))
   IF buy->(EOF())
      //Tr_MsgBox("Benutzer nicht gefunden")
      RETURN
   ENDIF
   
   cUserEmail := Trim(buy->Email)
   cUserName := Trim(Left(buy->Buyer,AT(" ",buy->Buyer)))
   
   IF Empty(cUserEmail)
      //Tr_MsgBox("Keine E-Mail-Adresse fr Benutzer " + cUserName + " gefunden")
      RETURN
   ENDIF

   // Get all record types
   hRecordTypes := GetRecordTypes()
   
   // Open TODO database
   NetUse("todo","todo")
   todo->(dbSetOrder(2)) // Assuming order by User
   
   // Collect todos for each reference type
   // Seek todos for this user
   todo->(dbSeek(Str(nUserId,2)+"N"))
   
   DO WHILE todo->User == nUserId .AND. ! todo->Done .AND. !todo->(EOF())
      IF AddWorkingDays(todo->Due,todo->Days*-1) <= AddWorkingDays(Date(),3) .AND. ! Empty(todo->Due)
         AAdd(aAllTodos, {;
            "UUID"=>Trim(todo->UUID),;
            "task" => Trim(todo->Task),;
            "due" => todo->Due,;
            "created" => Date(),; //todo->Created,; 
            "reftype" => IF(HHAsKey(hRecordTypes,Trim(todo->RefType)), hRecordTypes[Trim(todo->RefType)], "Unbekannt"),;
            "ref" => todo->Ref,;
            "priority" => IIF(todo->Due <= Date(), "Hoch", IIF(todo->Due <= Date()+2, "Mittel", "Niedrig"));
         })
      ENDIF
      todo->(dbSkip())
   ENDDO

   // Sort todos by due date
   ASort(aAllTodos,,,{|x,y| x["due"] < y["due"] })

   IF Len(aAllTodos) == 0
      //Tr_MsgBox("Keine offenen Aufgaben fr " + cUserName + " gefunden")
      RETURN
   ENDIF

   // Build email body
   cEmailBody := _EMAIL_HEADER(cUserName)
   
   FOR i := 1 TO Len(aAllTodos)
      cEmailBody += _BUILD_TASK_HTML(aAllTodos[i], i)
   NEXT
   
   cEmailBody += _EMAIL_FOOTER()

   //cUserEmail := "amos.engelking@engelking.de" // For testing only
   // Send email
   SendMail({{cUserEmail,cUserName}}, "Deine offenen Aufgaben - " + DtoC(Date()), cEmailBody,,,, .T.)
   

RETURN

FUNCTION _BUILD_TASK_HTML(hTask, nTaskNum)
   LOCAL cHTML := ""
   LOCAL cDueText
   LOCAL cCreatedText
   LOCAL nDaysDue, nDaysCreated
   
   // Calculate due date text
   nDaysDue := hTask["due"] - Date()
   IF nDaysDue < 0
      cDueText := "šberf„llig (" + LTrim(Str(Abs(nDaysDue))) + " Tage)"
   ELSEIF nDaysDue == 0
      cDueText := "Heute"
   ELSEIF nDaysDue == 1
      cDueText := "Morgen"
   ELSE
      cDueText := "in " + LTrim(Str(nDaysDue)) + " Tagen"
   ENDIF   

   cHTML := "<!-- Task Item " + LTrim(Str(nTaskNum)) + " -->" + CRLF
   cHTML += '<div class="task-item">' + CRLF
   cHTML += '  <div class="task-name"><a href="trader: -F TodoList('+"'"+hTask["UUID"]+"'"+')">' + hTask["task"] + '</a></div>' + CRLF
   cHTML += '  <div class="task-details">' + CRLF
   cHTML += '    <span class="task-priority priority-' + Lower(hTask["priority"]) + '">' + cDueText + '</span> - '   
   cHTML += '<strong>' + hTask["reftype"] + " "+LTrim(Str(hTask["ref"]))+'</strong>'+ CRLF
   cHTML += '  </div>' + CRLF
   cHTML += '</div>' + CRLF + CRLF

RETURN cHTML

#xcommand TEXT INTO <v> => #pragma __text|<v>+=%s+hb_eol()
FUNCTION _EMAIL_HEADER(cName)
   LOCAL cHTML := ""

   TEXT INTO cHTML
   <!DOCTYPE html>
   <html lang="de">
   <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Aufgaben-Erinnerung</title>
    <style>
        /* Engelking Farben */
        :root {
            --dunkelblau: #003972;
            --mint: #7CEAEA;
            --sand: #F4DEA2;
            --hellblau: #E6F8F8;
            --white: #ffffff;
            --text-dark: #333333;
            --text-light: #666666;
        }

        /* Reset und Base Styles */
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: var(--text-dark);
            background-color: #f5f5f5;
        }

        /* Container */
        .email-container {
            max-width: 600px;
            margin: 20px auto;
            background-color: var(--white);
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 57, 114, 0.1);
            overflow: hidden;
        }

        /* Header */
        .header {
            background: linear-gradient(135deg, var(--dunkelblau) 0%, #004a8c 100%);
            color: var(--white);
            padding: 30px 20px;
            text-align: center;
        }

         .logo img {
            width: 120px;
            height: auto;
            max-height: 40px;
         }

        .header h1 {
            font-size: 24px;
            font-weight: bold;
            margin-bottom: 8px;
        }

        .header .subtitle {
            font-size: 16px;
            opacity: 0.9;
            font-weight: 300;
        }

        /* Content */
        .content {
            padding: 40px 30px;
        }

        .greeting {
            font-size: 18px;
            color: var(--dunkelblau);
            margin-bottom: 20px;
            font-weight: 600;
        }

        .intro-text {
            font-size: 16px;
            color: var(--text-dark);
            margin-bottom: 30px;
            line-height: 1.7;
        }

        /* Task Section */
        .task-section {
            background-color: var(--hellblau);
            border-left: 4px solid var(--mint);
            padding: 25px;
            margin: 30px 0;
            border-radius: 0 6px 6px 0;
        }

        .task-header {
            display: flex;
            align-items: center;
            margin-bottom: 20px;
        }

        .task-icon {
            width: 24px;
            height: 24px;
            background-color: var(--dunkelblau);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin-right: 12px;
            color: var(--white);
            font-weight: bold;
            font-size: 14px;
        }

        .task-title {
            font-size: 18px;
            font-weight: 600;
            color: var(--dunkelblau);
        }

        .task-item {
            background-color: var(--white);
            border: 1px solid #e0e0e0;
            border-radius: 6px;
            padding: 20px;
            margin-bottom: 15px;
            transition: box-shadow 0.3s ease;
        }

        .task-item:hover {
            box-shadow: 0 2px 8px rgba(0, 57, 114, 0.1);
        }

        .task-name {
            font-size: 16px;
            font-weight: 600;
            color: var(--dunkelblau);
            margin-bottom: 8px;
        }

         .task-name a {
            color: var(--dunkelblau);
            text-decoration: none;
            font-weight: 600;
            transition: color 0.3s ease;
         }

         .task-name a:hover {
            color: #004a8c;
            text-decoration: underline;
         }

         .task-name a:visited {
            color: var(--dunkelblau);
         }

        .task-details {
            font-size: 14px;
            color: var(--text-light);
            margin-bottom: 10px;
        }

        .task-priority {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 10px;
            font-weight: 600;
            text-transform: uppercase;
        }

        .priority-hoch {
            background-color: #ff4757;
            color: white;
        }

        .priority-mittel {
            background-color: var(--sand);
            color: var(--dunkelblau);
        }

        .priority-niedrig {
            background-color: var(--mint);
            color: var(--dunkelblau);
        }

        /* Action Button */
        .action-section {
            text-align: center;
            margin: 40px 0;
        }

        .cta-button {
            display: inline-block;
            background: linear-gradient(135deg, var(--dunkelblau) 0%, #004a8c 100%);
            color: var(--white);
            text-decoration: none;
            padding: 15px 35px;
            border-radius: 25px;
            font-size: 16px;
            font-weight: 600;
            transition: all 0.3s ease;
            box-shadow: 0 4px 12px rgba(0, 57, 114, 0.3);
        }

        .cta-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 16px rgba(0, 57, 114, 0.4);
        }

        /* Footer */
        .footer {
            background-color: #f8f9fa;
            padding: 30px;
            text-align: center;
            border-top: 1px solid #e0e0e0;
        }

        .footer-text {
            font-size: 14px;
            color: var(--text-light);
            margin-bottom: 15px;
        }

        .unsubscribe {
            font-size: 12px;
            color: var(--text-light);
        }

        .unsubscribe a {
            color: var(--dunkelblau);
            text-decoration: none;
        }

        /* Responsive */
        @media (max-width: 480px) {
            .email-container {
                margin: 10px;
                border-radius: 0;
            }
            
            .content {
                padding: 30px 20px;
            }
            
            .task-section {
                padding: 20px 15px;
            }
            
            .header {
                padding: 25px 15px;
            }
        }
    </style>
   </head>
   <body>
    <div class="email-container">
        <!-- Header -->
        <div class="header">
            <div class="logo"><img src="https://db.engelking.de/trader/images/220914_engelking_logo_farbe_RGB_negativ.png" /></div>
            <h1>Aufgaben-Erinnerung</h1>
            <div class="subtitle">Deine offenen To-Dos im šberblick</div>
        </div>

        <!-- Content -->
        <div class="content">
   ENDTEXT
   cHtml += '<div class="greeting">Hallo '+cName+',</div>'
   TEXT INTO cHTML
            
            
            <div class="intro-text">
                du hast noch offene Aufgaben, die deine Aufmerksamkeit ben”tigen. 
                Hier ist eine šbersicht deiner ausstehenden To-Dos:
            </div>

            <!-- Task Section -->
            <div class="task-section">
                <div class="task-header">
                    <div class="task-icon">!</div>
                    <div class="task-title">Offene Aufgaben</div>
                </div>            
   ENDTEXT   

RETURN cHTML

FUNCTION _EMAIL_FOOTER()
   LOCAL cHTML := ""
   
   TEXT INTO cHTML
            </div>
            <!-- Action Section -->
            <div class="action-section">
                <a href="trader: -F TodoList" class="cta-button">
                    Aufgaben verwalten
                </a>
            </div>

            <div class="intro-text">
                Bleibe organisiert und verpasse keine wichtigen Termine!
            </div>
        </div>

        <!-- Footer -->
        <div class="footer">
            <div class="footer-text">
                <strong>Engelking</strong><br>
                innovativ handeln, nachhaltig wirken, gemeinsam wachsen
            </div>
        </div>
    </div>
   </body>
   </html>
   ENDTEXT

RETURN cHTML

// Convenience function to send todos for current user
PROC SEND_MY_TODOS()
   SEND_USER_TODO_EMAIL(SystemUser():Id)
RETURN



