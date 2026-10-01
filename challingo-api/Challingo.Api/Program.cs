//var builder = WebApplication.CreateBuilder(args);

//// Add services to the container.

//builder.Services.AddControllers();
//// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
//builder.Services.AddOpenApi();

//var app = builder.Build();

//// Configure the HTTP request pipeline.
//if (app.Environment.IsDevelopment())
//{
//    app.MapOpenApi();
//}

//app.UseAuthorization();

//app.MapControllers();



//app.Run();


using Challingo.Api;
using Challingo.Api.Extensions;
using Challingo.Infrastructure.Storage;

var apiEnvPath = FindEnvFilePath();
if (apiEnvPath is not null)
{
    DotNetEnv.Env.Load(apiEnvPath);
}

static string? FindEnvFilePath()
{
    var dir = new DirectoryInfo(Directory.GetCurrentDirectory());
    while (dir is not null)
    {
        var candidate = Path.Combine(dir.FullName, ".env");
        if (File.Exists(candidate))
        {
            return candidate;
        }

        dir = dir.Parent;
    }

    return null;
}

var builder = WebApplication.CreateBuilder(args);

builder
    .AddScaffoldHost()
    .AddApiServices()
    .AddErrorHandling()
    .AddDataBase()
    .AddApplicationServeices()
    .AddOtpAndAuthServices()
    .AddAuthenticationServices()
    .AddGoogleAuth()
    .AddScaffoldRedis()
    .AddScaffoldRealtime()
    .AddSwagger();

builder.Services.AddScaffoldFileStorage();

var app = builder.Build();

app.LogGoogleSignInConfiguration();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

await app.ApplyScaffoldStartupAsync();
await app.SeedInitialDataAsync();

app.UseScaffoldPipeline();
app.UseRouting();
app.UseCors("AllowSpecificOrigin");

app.UseSwagger();
app.UseSwaggerUI();

app.UseAuthentication();
app.UseAuthorization();

app.UseScaffoldRateLimiter();
app.UseMiddleware<Challingo.Api.Extensions.IdempotencyMiddleware>();

app.MapControllers();
app.MapScaffoldRealtime();

app.Run();