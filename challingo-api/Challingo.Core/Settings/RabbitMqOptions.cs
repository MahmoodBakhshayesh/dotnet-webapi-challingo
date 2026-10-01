namespace Challingo.Core.Settings;

public sealed class RabbitMqOptions
{
    public bool Enabled { get; set; }
    public string HostName { get; set; } = "rabbitmq";
    public int Port { get; set; } = 5672;
    public string UserName { get; set; } = "guest";
    public string Password { get; set; } = "guest";
    public string EmailQueueName { get; set; } = "projectname.email.outbound";
    public string SmsOtpQueueName { get; set; } = "projectname.otp.sms";
    public string EmailDeadLetterQueueName { get; set; } = "projectname.email.deadletter";
    public string SmsOtpDeadLetterQueueName { get; set; } = "projectname.otp.sms.deadletter";
}
