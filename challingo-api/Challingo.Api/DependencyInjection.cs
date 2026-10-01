using Challingo.Core.Domain.IdentityEntities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Services;
using Challingo.Infrastructure.DbContexts;
using Challingo.Infrastructure;
using Challingo.Infrastructure.Repositories;
using Challingo.Core.Settings;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Options;
using Challingo.Core.Puzzles;
using Microsoft.IdentityModel.Tokens;
using Newtonsoft.Json.Serialization;
using System.Security.Claims;
using System.Text;


namespace Challingo.Api
{
    public static class DependencyInjection
    {
        public static WebApplicationBuilder AddApiServices(this WebApplicationBuilder builder)
        {
            builder.Services.AddControllers(options =>
            {
                options.ReturnHttpNotAcceptable = true;
            }).AddNewtonsoftJson(option =>
            {
                //option.SerializerSettings.ReferenceLoopHandling =Newtonsoft.Json.ReferenceLoopHandling.Ignore;

                option.SerializerSettings.ContractResolver = new CamelCasePropertyNamesContractResolver();
            });

            // Prefer Cors:AllowedOrigins from config (deploy/api.env); fall back to localhost for local dev.
            var configuredOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
                ?? builder.Configuration.GetSection("Cors").Get<CorsSettings>()?.AllowedOrigins
                ?? [];
            var corsOrigins = configuredOrigins
                .Where(o => !string.IsNullOrWhiteSpace(o))
                .Select(o => o.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();
            if (corsOrigins.Length == 0)
            {
                // Next.js dev may use localhost or 127.0.0.1 — browsers treat them as different origins.
                corsOrigins =
                [
                    "http://localhost:3000",
                    "http://127.0.0.1:3000",
                    "http://localhost:3001",
                    "http://127.0.0.1:3001",
                    "https://localhost:3000",
                    "https://127.0.0.1:3000",
                    "https://localhost:3001",
                    "https://127.0.0.1:3001",
                ];
            }

            builder.Services.AddCors(options =>
            {
                options.AddPolicy("AllowSpecificOrigin", policy =>
                    policy.WithOrigins(corsOrigins)
                        .AllowAnyHeader()
                        .AllowAnyMethod()
                        .AllowCredentials());
            });
            return builder;
        }

        public static WebApplicationBuilder AddDataBase(this WebApplicationBuilder builder)
        {
            builder.Services.AddDbContext<AppDbContext>(options =>
            {
                //options.UseSqlServer(builder.Configuration.GetConnectionString("DataBase"));
                options.UseNpgsql(builder.Configuration.GetConnectionString("Database"));
                // EF Core 9+ blocks MigrateAsync when the model drifts from the last migration.
                // Allow migrate so local/dev can boot; add a migration when the model changes for real.
                options.ConfigureWarnings(w =>
                    w.Ignore(Microsoft.EntityFrameworkCore.Diagnostics.RelationalEventId.PendingModelChangesWarning));
            });
            return builder;
        }


        public static WebApplicationBuilder AddErrorHandling(this WebApplicationBuilder builder)
        {
            builder.Services.AddProblemDetails(options =>
            {

                options.CustomizeProblemDetails = context =>
                {
                    context.ProblemDetails.Extensions.TryAdd("requestId", context.HttpContext.TraceIdentifier);
                };
            });

            builder.Services.AddExceptionHandler<ValidationExceptionHandler>();
            builder.Services.AddExceptionHandler<GlobalExceptionHandler>();
            builder.Services.AddProblemDetails();

            return builder;
        }

        public static WebApplicationBuilder AddApplicationServeices(this WebApplicationBuilder builder)
        {

            builder.Services.AddOpenApi();
            builder.Services.AddHttpContextAccessor();

            builder.Services.AddTransient<ITokenProviderRepository, TokenProviderRepository>();
            builder.Services.AddTransient<ITokenProviderService, TokenProviderService>();


            builder.Services.AddTransient<IUserRepository, UserRepository>();
            builder.Services.AddTransient<IUserService, UserService>();

            builder.Services.AddTransient<IRoleService, RoleService>();

            builder.Services.AddTransient<IAuthRepository, AuthRepository>();
            builder.Services.AddTransient<IAuthService, AuthService>();


            builder.Services.AddTransient<IOrganizationRepository, OrganizationsRepository>();
            builder.Services.AddTransient<IOrganizationService, OrganizationService>();

            // Players: guest accounts, profile, time zone / country.
            builder.Services.AddTransient<IAccountRepository, AccountRepository>();
            builder.Services.AddTransient<IPlayerProfileService, PlayerProfileService>();

            // Puzzle engine (shared with the Worker) and the start / move / submit contract.
            builder.Services.AddChallingoGameEngine(builder.Environment.ContentRootPath);
            builder.Services.AddTransient<IPuzzleContentService, PuzzleContentService>();
            builder.Services.AddSingleton<IAttemptTokenService, AttemptTokenService>();
            builder.Services.AddTransient<IChallengeRepository, ChallengeRepository>();
            builder.Services.AddTransient<IChallengeService, ChallengeService>();

            // Competition: schedule, boards, stars, groups.
            builder.Services.AddChallingoCompetition();





            return builder;
        }

        public static WebApplicationBuilder AddAuthenticationServices(this WebApplicationBuilder builder)
        {

            builder.Services.AddIdentity<AppUser, AppRole>(option =>
            {
                // Guests have no email. Email uniqueness is enforced by the sign-up and guest-upgrade flows,
                // which check FindByEmailAsync before attaching an address.
                option.User.RequireUniqueEmail = false;

            })
                .AddEntityFrameworkStores<AppDbContext>()
                .AddUserStore<UserStore<AppUser, AppRole, AppDbContext, Guid, IdentityUserClaim<Guid>, AppUserRole, IdentityUserLogin<Guid>, IdentityUserToken<Guid>, IdentityRoleClaim<Guid>>>()
                .AddRoleStore<RoleStore<AppRole, AppDbContext, Guid, AppUserRole, IdentityRoleClaim<Guid>>>()
                .AddDefaultTokenProviders();




            builder.Services.Configure<JwtAuthOptions>(builder.Configuration.GetSection("Jwt"));
            JwtAuthOptions jwtAuthSettings = builder.Configuration.GetSection("Jwt").Get<JwtAuthOptions>()!;


            builder.Services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;

            })
            .AddJwtBearer(options =>
                {
                    options.TokenValidationParameters = new TokenValidationParameters
                    {
                        ValidIssuer = jwtAuthSettings.Issuer,
                        ValidAudience = jwtAuthSettings.Audience,
                        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtAuthSettings.Key)),
                    };
                });

            builder.Services.AddAuthorization();
            return builder;
        }

        public static WebApplicationBuilder AddSwagger(this WebApplicationBuilder builder)
        {
            builder.Services.AddEndpointsApiExplorer();
            builder.Services.AddSwaggerGen(option =>
            {
                option.OperationFilter<AppResponseEnvelopeOperationFilter>();
            });
            return builder;
        }

        public static WebApplicationBuilder AddGoogleAuth(this WebApplicationBuilder builder)
        {
            // Google Sign-In uses POST /api/auth/google with an ID token from the web GIS button.
            // Do not enable ASP.NET Google OAuth cookie middleware here — ClientId is validated in GoogleAuthService.

            //builder.Services.Configure<GoogleAuthOptions>(builder.Configuration.GetSection("Google"));
            //GoogleAuthOptions googleAuthOptions = builder.Configuration.GetSection("Google").Get<GoogleAuthOptions>()!;


            //builder.Services.AddAuthentication(options =>
            //{
            //    options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
            //    options.DefaultChallengeScheme = GoogleDefaults.AuthenticationScheme;

            //})
            //.AddGoogle(options =>
            //{
            //    options.ClientId = googleAuthOptions.ClientId;
            //    options.ClientSecret = googleAuthOptions.ClientSecret;
            //    options.Events.OnRemoteFailure = context =>
            //    {
            //        //var error = context.Failure.Message;

            //        //Console.WriteLine($"Google authentication failed: {context.Failure.Message}");
            //        return Task.CompletedTask;
            //    };
            //    options.Events.OnCreatingTicket = async context =>
            //    {
            //        var user = context.Principal;
            //        var email = user.FindFirstValue(ClaimTypes.Email);

            //        // Here you can perform additional user mapping or fetch additional details

            //        var userManager = context.HttpContext.RequestServices.GetRequiredService<UserManager<AppUser>>();
            //        var appUser = await userManager.FindByEmailAsync(email);

            //        if (appUser == null)
            //        {
            //            appUser = new AppUser
            //            {
            //                UserName = email,
            //                Email = email
            //            };
            //            await userManager.CreateAsync(appUser);
            //        }

            //        await userManager.AddToRoleAsync(appUser, "User");  // Assign a role if necessary
            //    };
            //});

            return builder;
        }

        public static WebApplicationBuilder AddThing(this WebApplicationBuilder builder)
        {

            return builder;
        }

    }
}
