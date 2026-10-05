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
// Die Doku-Beispiele funktionieren, unsere Aufrufe mit Teilnehmern als
// E-Mail-Text (Addresses.Add("x@y", "x@y", 0)) scheiterten mit 80004005.
// In den Beispielen ist die Liste leer oder enthaelt ein Address-Objekt aus
// einem Adressbuch. Deshalb hier mit der empfangenen Mail:
//   A. TeamTalk an der Mail, leere Teilnehmerliste
//   B. Teilnehmer als Address-Objekt aus dem Adressbuch (Global, Lokal,
//      Persoenlich - Suche ueber EMail), TeamChat ohne Mail
//   C. dasselbe als TeamTalk an der Mail
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

        // 1. Account
        var api = new DavidAPI();
        Account acc = Schritt("GetAccount", () => api.GetAccount());
        acc ??= Schritt("Logon AUTH", () => api.Logon("", "", "", "", "", "AUTH"));
        if (acc == null) return 1;
        Info("Angemeldet als", () => $"{acc.User.Name} ({acc.User.ID})");

        // 2. Mail
        string archivPfad = pfad[..pfad.LastIndexOf('\\')];
        Archive arch = Schritt("GetArchive", () => acc.GetArchive(archivPfad));
        if (arch == null) return 1;
        object mail = Schritt("GetArchiveEntryByID", () => (object)arch.GetArchiveEntryByID(pfad));
        if (mail == null && !Path.HasExtension(pfad))
            mail = Schritt("GetArchiveEntryByID .001", () => (object)arch.GetArchiveEntryByID(pfad + ".001"));
        if (mail != null) Info("Mail", () => (string)((dynamic)mail).Subject);

        // 3. ChatManager
        IChatManager cm = Schritt("ChatManager", () =>
            (IChatManager)Activator.CreateInstance(Type.GetTypeFromProgID("DVOBJAPILib.ChatManager", true)));
        if (cm == null) return 1;

        // A. TeamTalk an der Mail mit leerer Liste (wie Doku-Beispiel 1)
        if (mail != null)
            Senden("A TeamTalk leer", () => cm.StartChat(acc, acc.CreateAddressList(), mail));

        // Teilnehmer als Address-Objekte aus den Adressbuechern
        Addresses adr = acc.CreateAddressList();
        int gefunden = 0;
        foreach (string t in teilnehmer)
        {
            object a = AdresseSuchen(acc, t);
            if (a == null) { Console.WriteLine($"FEHLER  Adresse {t}: in keinem Adressbuch gefunden"); continue; }
            if (Schritt("Addresses.Add(Address) " + t, () => { adr.Add(a); return (object)"ok"; }) != null) gefunden++;
        }
        if (gefunden == 0) return 1;

        // B. TeamChat ohne Mail (wie Doku-Beispiel 2)
        Senden("B TeamChat Adressbuch", () => cm.StartChat(acc, adr));

        // C. TeamTalk an der Mail mit Adressbuch-Teilnehmern
        if (mail != null)
            Senden("C TeamTalk Adressbuch", () => cm.StartChat(acc, adr, mail));

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
