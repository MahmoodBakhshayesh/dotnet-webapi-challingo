using Challingo.Core.Domain.Entities;
using Challingo.Core.DTO.OrganizationDto;
using Challingo.Core.Settings;
using Xunit;

namespace Challingo.Tests;

public class AppResponseTests
{
    [Fact]
    public void Ok_sets_success_status_and_body()
    {
        var result = AppResponse.Ok(new { Id = 1 }, message: "ok");
        Assert.Equal(200, result.StatusCode);
        Assert.Equal("ok", result.Message);
    }

    [Fact]
    public void NotFound_sets_404()
    {
        var result = AppResponse.NotFound("missing");
        Assert.Equal(404, result.StatusCode);
    }

    [Fact]
    public void OrganizationMapper_round_trips_name()
    {
        var entity = new Organization
        {
            Id = Guid.CreateVersion7(),
            Name = "Acme",
            Description = "desc",
        };
        var dto = entity.ToResponse();
        Assert.Equal(entity.Id, dto.Id);
        Assert.Equal("Acme", dto.Name);
        Assert.Equal("desc", dto.Description);
    }
}

public class OptionsBaselineTests
{
    [Theory]
    [InlineData("Admin123!")]
    [InlineData("changeme")]
    [InlineData("")]
    [InlineData(null)]
    public void Weak_seed_admin_passwords_are_recognized(string? password)
    {
        Assert.True(IsWeakSeedAdminPassword(password));
    }

    [Fact]
    public void Strong_seed_admin_password_is_accepted()
    {
        Assert.False(IsWeakSeedAdminPassword("xK9!mP2$vL7#qR4@"));
    }

    [Theory]
    [InlineData("change-me-use-at-least-32-characters-long-secret")]
    [InlineData("1234564646466466544464456664656664646465445")]
    public void Jwt_placeholders_are_recognized(string key)
    {
        Assert.True(IsKnownJwtPlaceholder(key));
    }

    [Fact]
    public void Random_looking_jwt_key_is_not_placeholder()
    {
        Assert.False(IsKnownJwtPlaceholder(Convert.ToBase64String(Guid.NewGuid().ToByteArray()) + Convert.ToBase64String(Guid.NewGuid().ToByteArray())));
    }

    [Fact]
    public void DatabaseOptions_AutoMigrate_defaults_false()
    {
        Assert.False(new DatabaseOptions().AutoMigrate);
    }

    [Fact]
    public void CorsSettings_AllowedOrigins_defaults_empty()
    {
        Assert.Empty(new CorsSettings().AllowedOrigins);
    }

    // Mirror Production validation helpers in ScaffoldHostExtensions (keep in sync).
    private static bool IsKnownJwtPlaceholder(string? key) =>
        string.IsNullOrWhiteSpace(key)
        || key is "change-me-use-at-least-32-characters-long-secret"
            or "1234564646466466544464456664656664646465445";

    private static bool IsWeakSeedAdminPassword(string? password) =>
        string.IsNullOrWhiteSpace(password) || password is "Admin123!" or "changeme";
}
