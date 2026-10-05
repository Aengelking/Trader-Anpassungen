// DavidTeamTalk - prueft, ob sich ueber die DvApi32-COM-Schnittstelle ein
// TeamTalk (frueher "LiveComment") an einer David-Mail starten laesst.
//
// Aufruf:
//   DavidTeamTalk.exe "<Mailpfad>" [teilnehmer@engelking.de ...]
//   DavidTeamTalk.exe --doku [empfaenger]   (die beiden Beispiele der Doku)
//   DavidTeamTalk.exe --ohnejobid ["<Archivpfad>"]
//              Mails mit JobID 0 auflisten (Standard: eigener Posteingang)
//   DavidTeamTalk.exe --jobid "<Mailpfad>" [teilnehmer]
//              Mail mit JobID 0 TeamTalk-faehig machen: nacheinander
//              1 Save, 2 Teilnehmer als Cc + Save, 3 SRTo + Save
//              (wie im Doku-Beispiel), 4 Move in Entwuerfe und zurueck.
//              Nach jedem Schritt bis zu 60 s auf die JobID warten (der
//              Server vergibt sie verzoegert), dann StartChat versuchen,
//              Abbruch beim ersten Erfolg. NUR AN EINER TESTMAIL.
//   DavidTeamTalk.exe --ausgang "<Mailpfad>"
//              Mail mit JobID 0 in den Postausgang verschieben, dort
//              speichern (der Doku-Eintrag bekam im Ausgang eine JobID),
//              StartChat versuchen, zurueck in den Eingang, erneut pruefen.
//              NUR AN EINER TESTMAIL - im Ausgang koennte David sie senden.
//   DavidTeamTalk.exe --vergleich "<Mailpfad>" ["<Mailpfad>" ...]
//              je Mail die Felder, die vom Doku-Eintrag im Postausgang
//              abweichen (dort klappt StartChat, auch geladen), dazu
//              GetChatHistory und StartChat mit leerer Liste
//
//   Mailpfad   wie ihn David uebergibt, z. B.
//              \\ek-server3\david\archive\user\10004000\in\I44DF0D5
//              (ohne Endung wird zusaetzlich .001 versucht)
//   Teilnehmer Standard: inga@engelking.de
//
// Ergebnis bisher: Teilnehmer als Address-Objekt aus dem Adressbuch gehen
// (TeamChat startet), StartChat mit der empfangenen Mail als Bezug scheitert
// aber auch mit leerer Liste (80004005). Das Doku-Beispiel nimmt einen neuen,
// gespeicherten Eintrag aus GetSpecialArchive. Deshalb hier an der Mail:
//   1 Mail ueber GetArchive(Pfad).GetArchiveEntryByID (bisher)
//   2 Archiv ueber GetSpecialArchive(DvArchivePersonalIn)
//   3 Mail vorher speichern (Save), wie im Doku-Beispiel
//   4 Mail ueber GetArchiveEntries("Default").Item(i), Abgleich ueber _ID
// jeweils mit leerer Liste und mit den Teilnehmern aus dem Adressbuch.
// Bei Erfolg wird eine Testnachricht gesendet und der Thread geschlossen.

using System.Runtime.InteropServices;
using DvApi32;

static class Programm
{
    [STAThread]
    static int Main(string[] args)
    {
        if (args.Length == 0)
        {
            Console.WriteLine("Aufruf: DavidTeamTalk.exe \"<Mailpfad>\" [teilnehmer ...]");
            Console.WriteLine("        DavidTeamTalk.exe --doku [empfaenger]");
            Console.WriteLine("        DavidTeamTalk.exe --vergleich \"<Mailpfad>\" [...]");
            return 2;
        }
        for (int i = 0; i < args.Length; i++)
            Console.WriteLine($"Argument {i}: {args[i]}");
        if (args[0] == "--ausgang")
        {
            if (args.Length < 2 || !args[1].Contains('\\'))
            {
                Console.WriteLine("Aufruf: DavidTeamTalk.exe --ausgang \"<Mailpfad>\"");
                return 2;
            }
            return Ausgang(args[1]);
        }
        if (args[0] == "--ohnejobid")
            return OhneJobId(args.Length > 1 ? args[1] : null);
        if (args[0] == "--jobid")
        {
            if (args.Length < 2 || !args[1].Contains('\\'))
            {
                Console.WriteLine("Aufruf: DavidTeamTalk.exe --jobid \"<Mailpfad>\" [teilnehmer]");
                return 2;
            }
            return JobId(args[1], args.Length > 2 ? args[2] : "inga@engelking.de");
        }
        if (args[0] == "--vergleich")
        {
            if (args.Length < 2 || !args[1..].All(a => a.Contains('\\')))
            {
                Console.WriteLine("Aufruf: DavidTeamTalk.exe --vergleich \"<Mailpfad>\" [\"<Mailpfad>\" ...]");
                return 2;
            }
            return Vergleich(args[1..]);
        }
        if (args[0] == "--doku")
            return Doku(args.Length > 1 ? args[1] : "inga@engelking.de");
        string pfad = args[0];
        if (!pfad.Contains('\\'))
        {
            Console.WriteLine($"Kein Mailpfad: {pfad}");
            return 2;
        }
        string[] teilnehmer = args.Length > 1 ? args[1..] : new[] { "inga@engelking.de" };

        Console.WriteLine($"Prozess: {(Environment.Is64BitProcess ? "64" : "32")} Bit, Apartment {Thread.CurrentThread.GetApartmentState()}");

        // Account
        var api = new DavidAPI();
        Account acc = Schritt("GetAccount", () => api.GetAccount());
        acc ??= Schritt("Logon AUTH", () => api.Logon("", "", "", "", "", "AUTH"));
        if (acc == null) return 1;
        Info("Angemeldet als", () => $"{acc.User.Name} ({acc.User.ID})");

        // Mail
        string archivPfad = pfad[..pfad.LastIndexOf('\\')];
        Archive arch = Schritt("GetArchive", () => acc.GetArchive(archivPfad));
        if (arch == null) return 1;
        object mail = Schritt("GetArchiveEntryByID", () => (object)arch.GetArchiveEntryByID(pfad));
        if (mail == null && !Path.HasExtension(pfad))
            mail = Schritt("GetArchiveEntryByID .001", () => (object)arch.GetArchiveEntryByID(pfad + ".001"));
        if (mail != null) Info("Mail", () => (string)((dynamic)mail).Subject);

        // ChatManager
        IChatManager cm = Schritt("ChatManager", () =>
            (IChatManager)Activator.CreateInstance(Type.GetTypeFromProgID("DVOBJAPILib.ChatManager", true)));
        if (cm == null) return 1;

        if (mail == null) return 1;
        Info("Mail _ID", () => Convert.ToString(((dynamic)mail)._ID));
        Info("Mail Typ", () => Convert.ToString(((dynamic)mail).Type));
        Info("Mail Archiv", () => (string)((dynamic)mail).Parent.FullPath);

        // Teilnehmer als Address-Objekte aus den Adressbuechern
        Addresses adr = acc.CreateAddressList();
        foreach (string t in teilnehmer)
        {
            object a = AdresseSuchen(acc, t);
            if (a == null) { Console.WriteLine($"FEHLER  Adresse {t}: in keinem Adressbuch gefunden"); continue; }
            Schritt("Addresses.Add(Address) " + t, () => { adr.Add(a); return (object)"ok"; });
        }

        // 1. wie bisher
        Variante(cm, acc, adr, "1 GetArchive", mail);

        // 2. Archiv ueber GetSpecialArchive(PersonalIn)
        string vollPfad = Path.HasExtension(pfad) ? pfad : pfad + ".001";
        Archive eingang = Schritt("GetSpecialArchive PersonalIn",
            () => acc.GetSpecialArchive(DvArchiveTypes.DvArchivePersonalIn));
        if (eingang != null)
        {
            Info("Posteingang", () => (string)((dynamic)eingang).FullPath);
            object m2 = Schritt("Posteingang GetArchiveEntryByID", () => (object)eingang.GetArchiveEntryByID(vollPfad));
            if (m2 != null) Variante(cm, acc, adr, "2 GetSpecialArchive", m2);
        }

        // 3. nach Save
        if (Schritt("Save", () => { ((dynamic)mail).Save(); return (object)"ok"; }) != null)
            Variante(cm, acc, adr, "3 nach Save", mail);

        // 4. ueber GetArchiveEntries, Abgleich ueber _ID
        string id = Lesen(() => Convert.ToString(((dynamic)mail)._ID));
        object liste = Schritt("GetArchiveEntries Default", () => (object)arch.GetArchiveEntries("Default"));
        if (liste != null)
        {
            dynamic items = liste;
            object m4 = null;
            int anzahl = 0;
            try { anzahl = (int)items.Count; } catch { }
            for (int i = 0; i < anzahl && m4 == null; i++)
            {
                try
                {
                    dynamic it = items.Item(i);
                    if (Convert.ToString(it._ID) == id) m4 = (object)it;
                }
                catch { }
            }
            if (m4 == null) Console.WriteLine($"FEHLER  GetArchiveEntries: _ID {id} nicht unter {anzahl} Eintraegen");
            else Variante(cm, acc, adr, "4 GetArchiveEntries", m4);
        }

        return 0;
    }

    // Die beiden C#-Beispiele der DvAPI32-Doku, so nah wie moeglich am Original:
    //  - "Create and read a LiveComment" (HowToDo/CS/CSCreateAndReadLiveComment):
    //    neuen Eintrag im Postausgang anlegen, SRTo setzen, Save, dann StartChat
    //    mit LEERER Adressliste und dem Eintrag als Topic, danach GetChatHistory.
    //  - "Create a TeamChat" (IChatThread-Beispiel): erste Adresse aus dem lokalen
    //    Adressbuch als Address-Objekt, StartChat ohne Topic.
    // ACHTUNG: Der Eintrag liegt im Postausgang - David koennte ihn an den
    // Empfaenger senden. Deshalb Standard-Empfaenger inga@engelking.de.
    static int Doku(string empfaenger)
    {
        Console.WriteLine($"Prozess: {(Environment.Is64BitProcess ? "64" : "32")} Bit, Apartment {Thread.CurrentThread.GetApartmentState()}");
        var api = new DavidAPI();
        Account acc = Schritt("GetAccount", () => api.GetAccount());
        if (acc == null) return 1;
        Info("Angemeldet als", () => $"{acc.User.Name} ({acc.User.ID})");
        IChatManager cm = Schritt("ChatManager", () =>
            (IChatManager)Activator.CreateInstance(Type.GetTypeFromProgID("DVOBJAPILib.ChatManager", true)));
        if (cm == null) return 1;

        // Beispiel 1: LiveComment an neuem Eintrag
        Addresses leer = acc.CreateAddressList();
        Archive ausgang = Schritt("GetSpecialArchive PersonalOut",
            () => acc.GetSpecialArchive(DvArchiveTypes.DvArchivePersonalOut));
        object eintrag = ausgang == null ? null : Schritt("CreateArchiveEntry EMail",
            () => (object)ausgang.CreateArchiveEntry(DvItemTypes.DvEMailItem));
        if (eintrag != null)
        {
            Schritt("SRTo + Save", () =>
            {
                dynamic e = eintrag;
                e.Fields.Item("SRTo").Value = empfaenger;
                e.Save();
                return (object)"ok";
            });
            Senden("Doku LiveComment", () => cm.StartChat(acc, leer, eintrag));
            Info("GetChatHistory", () =>
            {
                dynamic verlauf = cm.GetChatHistory(eintrag, leer);
                return $"{verlauf.Count} Nachrichten, {leer.Count} Teilnehmer";
            });
        }

        // Beispiel 2: TeamChat mit Adresse aus dem lokalen Adressbuch
        Addresses adr = acc.CreateAddressList();
        object adresse = Schritt("LocalAddressBook.Item(0)", () => (object)acc.LocalAddressBook.Item(0));
        if (adresse != null)
        {
            Info("Adresse", () => (string)((dynamic)adresse).DisplayName);
            Schritt("Addresses.Add(Address)", () => (object)adr.Add(adresse));
            Senden("Doku TeamChat", () => cm.StartChat(acc, adr));
        }
        return 0;
    }

    // Address-Objekt fuer eine E-Mail-Adresse suchen. Die Adressbuecher haben
    // nur Item(i)/Count, daher alle Eintraege durchgehen und EMail vergleichen.
    static object AdresseSuchen(Account acc, string email)
    {
        var buecher = new (string Name, Func<object> Holen)[]
        {
            ("GlobalAddressBook", () => acc.GlobalAddressBook),
            ("LocalAddressBook", () => acc.LocalAddressBook),
            ("PersonalAddressBook", () => acc.PersonalAddressBook),
        };
        foreach (var (name, holen) in buecher)
        {
            object o = Schritt(name, holen);
            if (o == null) continue;
            dynamic buch = o;
            int anzahl;
            try { anzahl = (int)buch.Count; }
            catch (Exception e) { Console.WriteLine($"FEHLER  {name}.Count: {e.HResult:X8}"); continue; }
            Console.WriteLine($"        {name}: {anzahl} Eintraege");
            for (int i = 0; i < anzahl; i++)
            {
                dynamic a;
                string mail;
                try { a = buch.Item(i); mail = (string)a.EMail; }
                catch { continue; }
                if (i < 3) Console.WriteLine($"          [{i}] {Lesen(() => (string)a.DisplayName)} <{mail}>");
                if (string.Equals(mail?.Trim(), email, StringComparison.OrdinalIgnoreCase))
                {
                    Console.WriteLine($"OK      {email} in {name}[{i}]: {Lesen(() => (string)a.DisplayName)}, "
                        + $"UID {Lesen(() => Convert.ToString(a.UID))}, Typ {Lesen(() => Convert.ToString(a.Type))}");
                    return (object)a;
                }
            }
        }
        return null;
    }

    static string Lesen(Func<string> f)
    {
        try { return f(); } catch (Exception e) { return $"?({e.HResult:X8})"; }
    }

    // StartChat an der Mail einmal mit leerer Liste, einmal mit Teilnehmern.
    static void Variante(IChatManager cm, Account acc, Addresses adr, string name, object mail)
    {
        Senden(name + " leer", () => cm.StartChat(acc, acc.CreateAddressList(), mail));
        Senden(name + " Teilnehmer", () => cm.StartChat(acc, adr, mail));
    }

    // Was unterscheidet empfangene Mails vom Doku-Eintrag, an dem StartChat
    // funktioniert (auch geladen aus dem Postausgang)? Fuer jede Mail: die
    // Felder, die vom Doku-Eintrag abweichen, GetChatHistory und StartChat mit
    // leerer Liste. Mehrere Mails auf einmal, z. B. externe Kundenmail,
    // interne Mail eines Kollegen, Mail mit von Hand gestartetem TeamTalk.
    static int Vergleich(string[] pfade)
    {
        var api = new DavidAPI();
        Account acc = Schritt("GetAccount", () => api.GetAccount());
        if (acc == null) return 1;
        IChatManager cm = Schritt("ChatManager", () =>
            (IChatManager)Activator.CreateInstance(Type.GetTypeFromProgID("DVOBJAPILib.ChatManager", true)));
        if (cm == null) return 1;

        // Doku-Eintrag im Postausgang: Empfaenger inga@ oder anliegen@
        object doku = null;
        Archive ausgang = Schritt("GetSpecialArchive PersonalOut",
            () => acc.GetSpecialArchive(DvArchiveTypes.DvArchivePersonalOut));
        if (ausgang != null)
        {
            dynamic items = Schritt("Postausgang GetArchiveEntries", () => (object)ausgang.GetArchiveEntries("Default"));
            int n = 0;
            try { n = (int)items.Count; } catch { }
            for (int i = n - 1; i >= 0 && doku == null; i--)
            {
                try
                {
                    dynamic it = items.Item(i);
                    string an = Convert.ToString(it.Fields.Item("SRTo").Value) ?? "";
                    if (an.Contains("inga@", StringComparison.OrdinalIgnoreCase)
                        || an.Contains("anliegen@", StringComparison.OrdinalIgnoreCase))
                        doku = (object)it;
                }
                catch { }
            }
        }
        if (doku == null) { Console.WriteLine("FEHLER  Doku-Eintrag im Postausgang nicht gefunden (erst --doku laufen lassen)"); return 1; }
        var dokuFelder = Felder(doku);
        Console.WriteLine($"        Doku-Eintrag: {dokuFelder.GetValueOrDefault("FileName")}");

        foreach (string pfad in pfade)
        {
            Console.WriteLine();
            Console.WriteLine($"==== {pfad}");
            Archive arch = Schritt("GetArchive", () => acc.GetArchive(pfad[..pfad.LastIndexOf('\\')]));
            object mail = arch == null ? null : Schritt("GetArchiveEntryByID",
                () => (object)arch.GetArchiveEntryByID(Path.HasExtension(pfad) ? pfad : pfad + ".001"));
            if (mail == null) continue;
            Info("Betreff", () => (string)((dynamic)mail).Subject);
            var felder = Felder(mail);
            Console.WriteLine($"        {"Feld",-22} {"Mail",-40} Doku-Eintrag");
            foreach (var (name, wert) in felder)
            {
                string d = dokuFelder.GetValueOrDefault(name) ?? "";
                if (wert != d && !Unwichtig(name))
                    Console.WriteLine($"        {name,-22} {Kurz(wert, 40),-40} {Kurz(d, 40)}");
            }
            Info("GetChatHistory", () => $"{((dynamic)cm.GetChatHistory(mail, acc.CreateAddressList())).Count} Nachrichten");
            Senden("Mail", () => cm.StartChat(acc, acc.CreateAddressList(), mail));
        }
        return 0;
    }

    // Felder, die sich bei jeder Mail unterscheiden und nichts erklaeren
    static bool Unwichtig(string name) => name is "QID" or "RecNo" or "FileName" or "Subject" or "LongSubject"
        or "HTML" or "HTMLDisplayContent" or "SMTPHeader" or "Size" or "StatusTime" or "LastChangedTime"
        or "SendTimeMsg" or "ExStatusTime" or "MessageID" or "CharsetHtml";

    static string Kurz(string s, int n) => s.Length > n ? s[..(n - 3)] + "..." : s;

    static Dictionary<string, string> Felder(object eintrag)
    {
        var r = new Dictionary<string, string>();
        try
        {
            dynamic felder = ((dynamic)eintrag).Fields;
            int n = (int)felder.Count;
            for (int i = 0; i < n; i++)
            {
                try
                {
                    dynamic f = felder.Item(i);
                    string wert = Convert.ToString(f.Value) ?? "";
                    r.TryAdd((string)f.Name, wert.Replace("\r", " ").Replace("\n", " "));
                }
                catch { }
            }
        }
        catch (Exception e) { Console.WriteLine($"FEHLER  Fields: {e.HResult:X8} {e.Message}"); }
        return r;
    }

    // Bekommt eine empfangene Mail mit JobID 0 eine JobID, wenn wir sie
    // veraendern und speichern? Der Doku-Eintrag hatte nach SRTo + Save eine.
    static int JobId(string pfad, string teilnehmer)
    {
        var api = new DavidAPI();
        Account acc = Schritt("GetAccount", () => api.GetAccount());
        if (acc == null) return 1;
        IChatManager cm = Schritt("ChatManager", () =>
            (IChatManager)Activator.CreateInstance(Type.GetTypeFromProgID("DVOBJAPILib.ChatManager", true)));
        if (cm == null) return 1;
        string voll = Path.HasExtension(pfad) ? pfad : pfad + ".001";
        Archive arch = Schritt("GetArchive", () => acc.GetArchive(pfad[..pfad.LastIndexOf('\\')]));
        if (arch == null) return 1;
        dynamic mail = Schritt("GetArchiveEntryByID", () => (object)arch.GetArchiveEntryByID(voll));
        if (mail == null) return 1;
        Info("Betreff", () => (string)mail.Subject);
        string id = Lesen(() => Convert.ToString(mail._ID));
        string betreff = Lesen(() => Convert.ToString(mail.Subject));
        Info("JobID vorher", () => Convert.ToString(mail.Fields.Item("JobID").Value));
        if (Lesen(() => Convert.ToString(mail.Fields.Item("JobID").Value)) != "0")
        {
            Console.WriteLine("ABBRUCH Die Mail hat schon eine JobID - bitte eine Testmail mit JobID 0 nehmen.");
            return 1;
        }
        object adresse = AdresseSuchen(acc, teilnehmer);

        // Nach jedem Schritt: Mail neu laden (ueber _ID, falls sich der
        // Dateiname geaendert hat), JobID ausgeben, StartChat mit leerer Liste.
        bool Pruefen(string schritt)
        {
            object neu = null;
            try { neu = arch.GetArchiveEntryByID(voll); } catch { }
            if (neu == null)
            {
                try
                {
                    dynamic items = arch.GetArchiveEntries("Default");
                    for (int i = (int)items.Count - 1; i >= 0 && neu == null; i--)
                    {
                        dynamic it = items.Item(i);
                        if (Convert.ToString(it._ID) == id || Convert.ToString(it.Subject) == betreff) neu = (object)it;
                    }
                }
                catch { }
            }
            if (neu == null) { Console.WriteLine($"FEHLER  {schritt}: Mail nach dem Schritt nicht wiedergefunden"); return false; }
            mail = neu;
            // Der Server vergibt die JobID offenbar verzoegert: bis zu 60 s
            // alle 3 s neu laden, bis sie nicht mehr 0 ist.
            string job = Lesen(() => Convert.ToString(mail.Fields.Item("JobID").Value));
            var uhr = System.Diagnostics.Stopwatch.StartNew();
            while (job == "0" && uhr.Elapsed.TotalSeconds < 60)
            {
                Thread.Sleep(3000);
                string datei = Lesen(() => Convert.ToString(mail.Fields.Item("FileName").Value));
                if (!Path.HasExtension(datei)) datei += ".001";
                try { neu = arch.GetArchiveEntryByID(datei); } catch { neu = null; }
                if (neu != null) mail = neu;
                job = Lesen(() => Convert.ToString(mail.Fields.Item("JobID").Value));
            }
            Console.WriteLine($"        {schritt}: JobID {job} (nach {uhr.Elapsed.TotalSeconds:0} s)");
            Info($"{schritt}: Datei", () => Convert.ToString(mail.Fields.Item("FileName").Value));
            Info($"{schritt}: SRTo", () => Convert.ToString(mail.Fields.Item("SRTo").Value));
            ChatThread th = Schritt($"{schritt}: StartChat", () => cm.StartChat(acc, acc.CreateAddressList(), (object)mail));
            if (th == null) return false;
            Senden($"{schritt}", () => th);
            return true;
        }

        // 1. nur speichern
        if (Schritt("1 Save", () => { mail.Save(); return (object)"ok"; }) != null && Pruefen("1 Save")) return 0;

        // 2. Teilnehmer als Cc (Address-Objekt) und speichern
        if (adresse != null)
        {
            if (Schritt("2 RecipientsCc.Add", () => { mail.Fields.Item("RecipientsCc").Value.Add(adresse); return (object)"ok"; }) != null
                && Schritt("2 Save", () => { mail.Save(); return (object)"ok"; }) != null
                && Pruefen("2 Cc + Save")) return 0;
        }

        // 3. SRTo setzen und speichern, wie im Doku-Beispiel
        if (Schritt("3 SRTo", () => { mail.Fields.Item("SRTo").Value = teilnehmer; return (object)"ok"; }) != null
            && Schritt("3 Save", () => { mail.Save(); return (object)"ok"; }) != null
            && Pruefen("3 SRTo + Save")) return 0;

        // 4. in die Entwuerfe verschieben und zurueck
        Archive entwuerfe = Schritt("GetSpecialArchive PersonalDrafts",
            () => acc.GetSpecialArchive(DvArchiveTypes.DvArchivePersonalDrafts));
        if (entwuerfe != null
            && Schritt("4 Move Entwuerfe", () => { mail.Move(entwuerfe, true); return (object)"ok"; }) != null)
        {
            // In den Entwuerfen neu suchen (neue Datei), dann zurueck
            object dort = null;
            try
            {
                dynamic items = entwuerfe.GetArchiveEntries("Default");
                for (int i = (int)items.Count - 1; i >= 0 && dort == null; i--)
                {
                    dynamic it = items.Item(i);
                    if (Convert.ToString(it.Subject) == betreff) dort = (object)it;
                }
            }
            catch { }
            if (dort == null) { Console.WriteLine("FEHLER  4: Mail in den Entwuerfen nicht gefunden - bitte von Hand zurueckschieben!"); return 1; }
            Info("4 in Entwuerfen: JobID", () => Convert.ToString(((dynamic)dort).Fields.Item("JobID").Value));
            if (Schritt("4 Move zurueck", () => { ((dynamic)dort).Move(arch, true); return (object)"ok"; }) == null)
            {
                Console.WriteLine("        Mail liegt noch in den Entwuerfen - bitte von Hand zurueckschieben!");
                return 1;
            }
            Console.WriteLine("        Mail ist zurueck im Eingang.");
            if (Pruefen("4 Move hin und zurueck")) return 0;
        }
        Console.WriteLine("Keiner der Schritte hat eine JobID gebracht.");
        return 1;
    }

    // Mails ohne JobID (StartChat scheitert an ihnen) im Archiv auflisten.
    static int OhneJobId(string archivPfad)
    {
        var api = new DavidAPI();
        Account acc = Schritt("GetAccount", () => api.GetAccount());
        if (acc == null) return 1;
        Archive arch = archivPfad == null
            ? Schritt("GetSpecialArchive PersonalIn", () => acc.GetSpecialArchive(DvArchiveTypes.DvArchivePersonalIn))
            : Schritt("GetArchive", () => acc.GetArchive(archivPfad.TrimEnd('\\')));
        if (arch == null) return 1;
        dynamic items = Schritt("GetArchiveEntries", () => (object)arch.GetArchiveEntries("Default"));
        if (items == null) return 1;
        int n = 0, treffer = 0;
        try { n = (int)items.Count; } catch { }
        Console.WriteLine($"        {n} Eintraege, ohne JobID:");
        for (int i = n - 1; i >= 0; i--)
        {
            try
            {
                dynamic it = items.Item(i);
                if (Convert.ToString(it.Fields.Item("JobID").Value) != "0") continue;
                treffer++;
                Console.WriteLine($"        {Convert.ToString(it.Fields.Item("FileName").Value)}  "
                    + $"{Convert.ToString(it.Fields.Item("StatusTime").Value)}  "
                    + $"{Kurz(Convert.ToString(it.Fields.Item("SRFrom").Value) ?? "", 30),-30}  "
                    + $"{Kurz(Convert.ToString(it.Subject) ?? "", 60)}");
            }
            catch { }
        }
        Console.WriteLine($"        {treffer} Mails ohne JobID");
        return 0;
    }

    // Bekommt die Mail im Postausgang eine JobID, und behaelt sie sie nach dem
    // Zurueckschieben?
    static int Ausgang(string pfad)
    {
        var api = new DavidAPI();
        Account acc = Schritt("GetAccount", () => api.GetAccount());
        if (acc == null) return 1;
        IChatManager cm = Schritt("ChatManager", () =>
            (IChatManager)Activator.CreateInstance(Type.GetTypeFromProgID("DVOBJAPILib.ChatManager", true)));
        if (cm == null) return 1;
        Archive eingang = Schritt("GetArchive", () => acc.GetArchive(pfad[..pfad.LastIndexOf('\\')]));
        if (eingang == null) return 1;
        dynamic mail = Schritt("GetArchiveEntryByID",
            () => (object)eingang.GetArchiveEntryByID(Path.HasExtension(pfad) ? pfad : pfad + ".001"));
        if (mail == null) return 1;
        string betreff = Lesen(() => Convert.ToString(mail.Subject));
        Info("Betreff", () => betreff);
        Info("JobID vorher", () => Convert.ToString(mail.Fields.Item("JobID").Value));
        Info("SRTo vorher", () => Convert.ToString(mail.Fields.Item("SRTo").Value));
        if (Lesen(() => Convert.ToString(mail.Fields.Item("JobID").Value)) != "0")
        {
            Console.WriteLine("ABBRUCH Die Mail hat schon eine JobID - bitte eine Testmail mit JobID 0 nehmen.");
            return 1;
        }
        Archive ausgang = Schritt("GetSpecialArchive PersonalOut",
            () => acc.GetSpecialArchive(DvArchiveTypes.DvArchivePersonalOut));
        if (ausgang == null) return 1;

        // Neuester Eintrag mit dem Betreff im Archiv (nach Move neuer Dateiname)
        object Suchen(Archive a)
        {
            try
            {
                dynamic items = a.GetArchiveEntries("Default");
                for (int i = (int)items.Count - 1; i >= 0; i--)
                {
                    dynamic it = items.Item(i);
                    if (Convert.ToString(it.Subject) == betreff) return (object)it;
                }
            }
            catch { }
            return null;
        }
        void Zeigen(string schritt, dynamic e)
        {
            Info($"{schritt}: JobID", () => Convert.ToString(e.Fields.Item("JobID").Value));
            Info($"{schritt}: Status", () => Convert.ToString(e.Fields.Item("Status").Value));
            Info($"{schritt}: Datei", () => Convert.ToString(e.Fields.Item("FileName").Value));
        }

        if (Schritt("Move Postausgang", () => { mail.Move(ausgang, true); return (object)"ok"; }) == null) return 1;
        dynamic imAusgang = Suchen(ausgang);
        if (imAusgang == null) { Console.WriteLine("FEHLER  Mail im Postausgang nicht gefunden - bitte von Hand zurueckschieben!"); return 1; }
        Zeigen("im Ausgang", imAusgang);
        Schritt("Save im Ausgang", () => { imAusgang.Save(); return (object)"ok"; });
        imAusgang = Suchen(ausgang) ?? imAusgang;
        Zeigen("nach Save", imAusgang);
        Senden("im Ausgang", () => cm.StartChat(acc, acc.CreateAddressList(), (object)imAusgang));

        if (Schritt("Move zurueck", () => { imAusgang.Move(eingang, true); return (object)"ok"; }) == null)
        {
            Console.WriteLine("        Mail liegt noch im Postausgang - bitte von Hand zurueckschieben!");
            return 1;
        }
        dynamic zurueck = Suchen(eingang);
        if (zurueck == null) { Console.WriteLine("FEHLER  Mail im Eingang nicht wiedergefunden - bitte pruefen!"); return 1; }
        Zeigen("zurueck im Eingang", zurueck);
        Senden("zurueck im Eingang", () => cm.StartChat(acc, acc.CreateAddressList(), (object)zurueck));
        return 0;
    }

    static void Senden(string name, Func<ChatThread> start)
    {
        ChatThread th = Schritt(name + ": StartChat", start);
        if (th == null) return;
        Info(name + ": Thread", () => $"ID {th.ID}, LiveComment {th.InstantComment}");
        Schritt(name + ": SendMessage", () =>
            (object)th.SendMessage("Test Anliegen eroeffnen (DavidTeamTalk.exe). Bitte ignorieren.", DvTextTypes.DvTextPlain));
        Schritt(name + ": CloseThread", () => { th.CloseThread(); return (object)"ok"; });
    }

    static T Schritt<T>(string name, Func<T> f) where T : class
    {
        try
        {
            T r = f();
            Console.WriteLine($"OK      {name}");
            return r;
        }
        catch (Exception e)
        {
            Console.WriteLine($"FEHLER  {name}: {e.HResult:X8} {e.Message}");
            if (e is COMException ce && ce.ErrorCode != e.HResult)
                Console.WriteLine($"        COM-Code {ce.ErrorCode:X8}");
            return null;
        }
    }

    static void Info(string name, Func<string> f)
    {
        try { Console.WriteLine($"        {name}: {f()}"); }
        catch (Exception e) { Console.WriteLine($"        {name}: nicht lesbar ({e.HResult:X8})"); }
    }
}
