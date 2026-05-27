using System.Threading.Tasks;
using NeuraDeV.Models;

namespace NeuraDeV.Services;

/// Demo AI that mimics the on-screen "Police Job" flow. Swap with a real
/// Claude / Anthropic API client by implementing IAiService.
public sealed class MockAiService : IAiService
{
    public Task<ChatMessage> RespondAsync(string userInput)
    {
        var lower = userInput.ToLowerInvariant();
        var msg = new ChatMessage
        {
            Role = ChatRole.Assistant,
            Author = "NeuraDeV AI",
            IsAssistant = true
        };

        if (lower.Contains("police") || lower.Contains("polizei"))
        {
            msg.Text = "Verstanden! Ich werde ein komplettes Police Job System für FiveM erstellen. Hier ist der Plan:";
            msg.Plan.Add(new PlanStep { Title = "1. Datenbank erstellen", IsDone = true });
            msg.Plan.Add(new PlanStep { Title = "2. Server-Script entwickeln", IsDone = true });
            msg.Plan.Add(new PlanStep { Title = "3. Client-Script entwickeln", IsDone = true });
            msg.Plan.Add(new PlanStep { Title = "4. UI für Polizei Menü erstellen", IsDone = true });
            msg.Plan.Add(new PlanStep { Title = "5. Konfiguration hinzufügen", IsDone = true });
            msg.StatusLine = "Schritt 1/5: Datenbank erstellen";
            msg.Progress = 0.22;
        }
        else
        {
            msg.Text = "Bereit. Beschreibe dein Modul (FiveM Resource, C#-Service, UI-Komponente, SQL-Schema), und ich entwerfe die Architektur und schreibe den Code.";
        }

        return Task.FromResult(msg);
    }
}
