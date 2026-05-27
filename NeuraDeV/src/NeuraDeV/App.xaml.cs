using System.Windows;
using NeuraDeV.Engine.Security;

namespace NeuraDeV;

public partial class App : Application
{
    public App()
    {
        CrashGuard.Install(onCrash: ex => MessageBox.Show(
            $"NeuraDeV ist auf einen unerwarteten Fehler gestoßen:\n\n{ex.Message}",
            "NeuraDeV", MessageBoxButton.OK, MessageBoxImage.Error));
    }
}
