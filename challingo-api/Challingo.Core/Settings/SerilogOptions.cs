namespace Challingo.Core.Settings;

public sealed class SerilogOptions
{
    public bool Enabled { get; set; } = true;
    public string MinimumLevel { get; set; } = "Information";
    public bool WriteToFile { get; set; }
    public string FilePath { get; set; } = "logs/api-.log";
}
