namespace NeuraDeV.Models;

public enum CodeTokenKind
{
    Plain,
    Keyword,
    String,
    Number,
    Comment,
    Function,
    Identifier
}

public sealed record CodeToken(string Text, CodeTokenKind Kind);
