namespace Challingo.Core.Domain.Enums;

public enum AttemptStatus
{
    InProgress = 0,
    Solved = 1,
    Failed = 2,
    /// <summary>Submitted after the challenge window closed, or never submitted.</summary>
    Expired = 3,
}
