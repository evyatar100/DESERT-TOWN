# Hebrew spellcheck via the Windows ISpellChecker (he-IL). ASCII-only source.
# Exit: 0 clean, 1 findings, 2 usage/input error, 3 he-IL checker unavailable.
param(
    [string]$Json = '',            # translations-style JSON; default game-files/PBS/translations.json
    [string]$File = '',            # plain UTF-8 text file, one entry per line
    [string]$Text = '',            # literal text (non-ASCII via command line may be mangled; prefer -File)
    [string]$Allowlist = '',       # default: allowlist.txt next to SKILL.md
    [string]$Lang = 'he-IL',
    [int]$MaxSuggestions = 5
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$utf8 = New-Object System.Text.UTF8Encoding($false)
$skillDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
if (-not $Allowlist) { $Allowlist = Join-Path $skillDir 'allowlist.txt' }
if (-not (Test-Path -LiteralPath $Allowlist)) { [Console]::Error.WriteLine("ERROR: allowlist not found: $Allowlist"); exit 2 }

$src = @"
using System; using System.Runtime.InteropServices; using System.Collections.Generic;
using System.Runtime.InteropServices.ComTypes;
[ComImport, Guid("8E018A9D-2415-4677-BF08-794EA61F94BB"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface ISpellCheckerFactory {
  [return: MarshalAs(UnmanagedType.Interface)] object get_SupportedLanguages();
  int IsSupported([MarshalAs(UnmanagedType.LPWStr)] string tag);
  [return: MarshalAs(UnmanagedType.Interface)] ISpellChecker CreateSpellChecker([MarshalAs(UnmanagedType.LPWStr)] string tag);
}
[ComImport, Guid("B6FD0B71-E2BC-4653-8D05-F197E412770B"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface ISpellChecker {
  [return: MarshalAs(UnmanagedType.LPWStr)] string get_LanguageTag();
  [return: MarshalAs(UnmanagedType.Interface)] IEnumSpellingError Check([MarshalAs(UnmanagedType.LPWStr)] string text);
  [return: MarshalAs(UnmanagedType.Interface)] IEnumString Suggestions([MarshalAs(UnmanagedType.LPWStr)] string word);
}
[ComImport, Guid("803E3BD4-2828-4410-8290-418D1D73C762"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface IEnumSpellingError { [PreserveSig] int Next(out ISpellingError e); }
[ComImport, Guid("B7C82D61-FBE8-4B47-9B27-6C0D2E0DE0A3"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
public interface ISpellingError { uint get_StartIndex(); uint get_Length(); int get_CorrectiveAction(); }
public class HeSpell {
  ISpellChecker c;
  public static string Unsupported(string tag) {
    var f = (ISpellCheckerFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("7AB36653-1796-484B-BDFA-E74F1DB7C1DC")));
    return f.IsSupported(tag) == 0 ? tag : null;
  }
  public HeSpell(string tag) {
    var f = (ISpellCheckerFactory)Activator.CreateInstance(Type.GetTypeFromCLSID(new Guid("7AB36653-1796-484B-BDFA-E74F1DB7C1DC")));
    c = f.CreateSpellChecker(tag);
  }
  public List<string> Errors(string text) {
    var outs = new List<string>(); var en = c.Check(text); ISpellingError e;
    while (en.Next(out e) == 0) outs.Add(text.Substring((int)e.get_StartIndex(), (int)e.get_Length()));
    return outs;
  }
  public List<string> Suggest(string word, int max) {
    var outs = new List<string>(); var en = c.Suggestions(word); var buf = new string[1];
    while (outs.Count < max && en.Next(1, buf, IntPtr.Zero) == 0) outs.Add(buf[0]);
    return outs;
  }
}
"@
try {
Add-Type -TypeDefinition $src

if ([HeSpell]::Unsupported($Lang)) {
    [Console]::Error.WriteLine("ERROR: Windows spellchecker has no $Lang dictionary (Settings > Time & language > Language).")
    exit 3
}
$spell = New-Object HeSpell($Lang)

# ---- entries: key -> text ----
$entries = New-Object System.Collections.Specialized.OrderedDictionary
$nameWords = New-Object System.Collections.Generic.HashSet[string]
if ($Text) {
    $entries['text'] = $Text
} elseif ($File) {
    if (-not (Test-Path -LiteralPath $File)) { [Console]::Error.WriteLine("ERROR: not found: $File"); exit 2 }
    $n = 0
    foreach ($line in [IO.File]::ReadAllLines($File, $utf8)) { $n++; if ($line.Trim()) { $entries["line $n"] = $line } }
} else {
    if (-not $Json) { $Json = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $skillDir))) 'game-files\PBS\translations.json' }
    if (-not (Test-Path -LiteralPath $Json)) { [Console]::Error.WriteLine("ERROR: not found: $Json"); exit 2 }
    # JavaScriptSerializer keeps keys case-sensitive (Cancel vs CANCEL); ConvertFrom-Json rejects them.
    Add-Type -AssemblyName System.Web.Extensions
    $ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $ser.MaxJsonLength = [int]::MaxValue
    $doc = $ser.DeserializeObject([IO.File]::ReadAllText($Json, $utf8))
    foreach ($name in $doc['translations'].Keys) {
        $he = $doc['translations'][$name]['he']
        if (-not $he) { continue }
        $entries[$name] = [string]$he
        if ($name.StartsWith('NAME_')) {
            foreach ($w in ($he -split '[^\p{L}\p{M}]+')) { if ($w) { [void]$nameWords.Add($w) } }
        }
    }
}

# ---- allowlist (exact word, or word after 1-2 Hebrew prefix letters) ----
if ($entries.Count -eq 0) { [Console]::Error.WriteLine('ERROR: 0 entries to check (empty input or no translations/he values)'); exit 2 }
$allow = New-Object System.Collections.Generic.HashSet[string]
$allowRe = New-Object System.Collections.Generic.List[regex]
if ($true) {
    foreach ($line in [IO.File]::ReadAllLines($Allowlist, $utf8)) {
        $t = $line.Trim()
        if ($t.StartsWith('re:')) { $allowRe.Add([regex]('^(?:' + $t.Substring(3) + ')$')) }
        elseif ($t -and -not $t.StartsWith('#')) { [void]$allow.Add($t) }
    }
}
foreach ($w in $nameWords) { [void]$allow.Add($w) }
$prefixes = [string][char]0x05D1 + [char]0x05D4 + [char]0x05D5 + [char]0x05DB + [char]0x05DC + [char]0x05DE + [char]0x05E9
function Test-Allowed([string]$w) {
    if ($allow.Contains($w)) { return $true }
    foreach ($r in $allowRe) { if ($r.IsMatch($w)) { return $true } }
    for ($i = 1; $i -le 2 -and $i -lt $w.Length - 1; $i++) {
        if ($prefixes.IndexOf($w[$i - 1]) -lt 0) { break }
        if ($allow.Contains($w.Substring($i))) { return $true }
    }
    return $false
}

# ---- check ----
$findings = 0
$nl = [regex]'\\[nN]'
$codes = [regex]'\\(?:[bBrR.|!^<>{}]|[A-Za-z]+(?:\[[^\]]*\])?)'
$hebrew = [regex]('[' + [char]0x0590 + '-' + [char]0x05FF + ']')
foreach ($key in $entries.Keys) {
    # Essentials message codes are not words: newline codes become a line break, the rest are dropped.
    $text = $nl.Replace(([string]$entries[$key]), "`n")
    $text = $codes.Replace($text, '')
    $seen = New-Object System.Collections.Generic.HashSet[string]
    foreach ($w in $spell.Errors($text)) {
        if (-not $hebrew.IsMatch($w)) { continue }
        if (-not $seen.Add($w)) { continue }
        if (Test-Allowed $w) { continue }
        $sug = ($spell.Suggest($w, $MaxSuggestions)) -join ', '
        [Console]::Out.WriteLine("$key`t$w`t$sug")
        $findings++
    }
}
[Console]::Error.WriteLine("checked $($entries.Count) entries, $findings finding(s)")
if ($findings -gt 0) { exit 1 }
exit 0
} catch {
    [Console]::Error.WriteLine('ERROR: ' + $_.Exception.Message)
    exit 2
}
