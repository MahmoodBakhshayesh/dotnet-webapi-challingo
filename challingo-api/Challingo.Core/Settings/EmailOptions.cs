namespace Challingo.Core.Settings;

public sealed class EmailOptions
{
    public bool Enabled { get; set; }
    public string FromAddress { get; set; } = "";
    public string FromDisplayName { get; set; } = "Challingo";
    public string SmtpHost { get; set; } = "smtp.gmail.com";
    public int SmtpPort { get; set; } = 587;
    public string SmtpUsername { get; set; } = "";
    public string SmtpPassword { get; set; } = "";
    public string OtpSubject { get; set; } = "Your Challingo sign-in code";
    public string OtpHtmlTemplate { get; set; } =
        "<p>Your sign-in code is <strong>{code}</strong>. It expires in 5 minutes.</p>";
}
