using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;

namespace NeuraDeV.Models;

public enum ChatRole { User, Assistant }

public partial class ChatMessage : ObservableObject
{
    [ObservableProperty] private ChatRole role;
    [ObservableProperty] private string author = string.Empty;
    [ObservableProperty] private string text = string.Empty;
    [ObservableProperty] private string statusLine = string.Empty;
    [ObservableProperty] private double progress;        // 0..1, 0 hides bar
    [ObservableProperty] private bool isUser;
    [ObservableProperty] private bool isAssistant;

    public ObservableCollection<PlanStep> Plan { get; } = new();

    public bool HasPlan => Plan.Count > 0;
    public bool HasProgress => Progress > 0;
}
