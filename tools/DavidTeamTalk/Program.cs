// DavidTeamTalk - prueft, ob sich ueber die DvApi32-COM-Schnittstelle ein
// TeamTalk (frueher "LiveComment") an einer David-Mail starten laesst.
//
// Aufruf:
//   DavidTeamTalk.exe "<Mailpfad>" [teilnehmer@engelking.de ...]
//   DavidTeamTalk.exe --doku [empfaenger]   (die beiden Beispiele der Doku)
//
//   Mailpfad   wie ihn David uebergibt, z. B.
//              \\ek-server3\david\archive\user\10004000\in\I44DF0D5
//              (ohne Endung wird zusaetzlich .001 versucht)
//   Teilnehmer Standard: anliegen@engelking.de
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
            return 2;
        }
        if (args[0] == "--doku")
            return Doku(args.Length > 1 ? args[1] : "anliegen@engelking.de");
        string pfad = args[0];
        string[] teilnehmer = args.Length > 1 ? args[1..] : new[] { "anliegen@engelking.de" };

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
    // Empfaenger senden. Deshalb Standard-Empfaenger anliegen@engelking.de.
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
