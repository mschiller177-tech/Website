namespace NeuraDeV.Models;

public sealed class NavItem
{
    public required string Title { get; init; }
    public required string Icon { get; init; }
    public required string Key { get; init; }
    public bool IsActive { get; set; }
}
