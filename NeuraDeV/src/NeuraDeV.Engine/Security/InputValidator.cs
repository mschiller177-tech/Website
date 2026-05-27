using System.Text.RegularExpressions;

namespace NeuraDeV.Engine.Security;

/// <summary>Sanitises user input before it reaches the engine pipeline.</summary>
public sealed class InputValidator
{
    private const int MaxInputLength = 8_000;

    private static readonly Regex SuspiciousShell = new(
        @"(\brm\s+-rf\b|\bdel\s+/[sq]\b|format\s+c:|shutdown\s)",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    private static readonly Regex SecretLeak = new(
        @"(sk-[a-zA-Z0-9]{20,}|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{30,})",
        RegexOptions.Compiled);

    public bool TryValidate(string input, out string reason)
    {
        if (string.IsNullOrWhiteSpace(input))
        {
            reason = "Leere Eingabe."; return false;
        }
        if (input.Length > MaxInputLength)
        {
            reason = $"Eingabe zu lang ({input.Length} > {MaxInputLength} Zeichen)."; return false;
        }
        if (SuspiciousShell.IsMatch(input))
        {
            reason = "Destruktive Shell-Befehle erkannt — Aktion blockiert."; return false;
        }
        if (SecretLeak.IsMatch(input))
        {
            reason = "Mögliches Secret in der Eingabe erkannt — bitte entfernen."; return false;
        }

        reason = string.Empty;
        return true;
    }
}
