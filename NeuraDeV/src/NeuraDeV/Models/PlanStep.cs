using CommunityToolkit.Mvvm.ComponentModel;

namespace NeuraDeV.Models;

public partial class PlanStep : ObservableObject
{
    [ObservableProperty] private string title = string.Empty;
    [ObservableProperty] private bool isDone;
    [ObservableProperty] private bool isActive;
}
