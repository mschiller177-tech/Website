namespace NeuraDeV.Engine.Security;

/// <summary>
/// Three-tier permission model. The host app should set <see cref="Current"/>
/// based on the logged-in user. The engine consults <see cref="Require"/> for
/// privileged operations (file writes outside the project, model downloads,
/// SQL DROP, etc.).
/// </summary>
public sealed class PermissionGuard
{
    public Role Current { get; set; } = Role.Developer;

    public bool Has(Role minimum) => Current >= minimum;

    public void Require(Role minimum)
    {
        if (!Has(minimum))
            throw new UnauthorizedAccessException(
                $"Rolle {Current} nicht ausreichend — benötigt mindestens {minimum}.");
    }
}

public enum Role { User = 0, Developer = 1, Admin = 2 }
