using System.Collections.ObjectModel;
using System.Windows.Media;

namespace NeuraDeV.Models;

public sealed class ProjectNode
{
    public required string Name { get; init; }
    public bool IsFolder { get; init; }
    public bool IsExpanded { get; init; } = true;

    public string Icon =>
        IsFolder              ? "" :   // Folder
        Name.EndsWith(".lua") ? "" :   // Code
        Name.EndsWith(".sql") ? "" :   // Database
        Name.EndsWith(".html")? "" :   // Globe
        Name.EndsWith(".css") ? "" :   // Color
        Name.EndsWith(".js")  ? "" :   // Code
        Name.EndsWith(".md")  ? "" :   // Page
                                "";

    public Brush IconBrush
    {
        get
        {
            string hex =
                IsFolder              ? "#FFEAB308" :
                Name.EndsWith(".lua") ? "#FF60A5FA" :
                Name.EndsWith(".sql") ? "#FFF59E0B" :
                Name.EndsWith(".html")? "#FFEF4444" :
                Name.EndsWith(".css") ? "#FF3FB8FF" :
                Name.EndsWith(".js")  ? "#FFFBBF24" :
                Name.EndsWith(".md")  ? "#FF8A8AAA" :
                                        "#FF8A8AAA";
            return new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex)!);
        }
    }

    public ObservableCollection<ProjectNode> Children { get; init; } = new();
}
