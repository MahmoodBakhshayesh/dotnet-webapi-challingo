using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.IdentityEntities;

namespace Challingo.Infrastructure.DbContexts.Configurations;

public sealed class PlayerProfileConfiguration : IEntityTypeConfiguration<PlayerProfile>
{
    public void Configure(EntityTypeBuilder<PlayerProfile> builder)
    {
        builder.ToTable("PlayerProfiles");
        builder.HasIndex(x => x.UserId).IsUnique();
        builder.HasIndex(x => x.CountryCode);
        builder.Property(x => x.DisplayName).HasMaxLength(20).IsRequired();
        builder.Property(x => x.TimeZoneId).HasMaxLength(64).IsRequired();
        builder.Property(x => x.PreviousTimeZoneId).HasMaxLength(64);
        builder.Property(x => x.CountryCode).HasMaxLength(2);
        builder.HasOne<AppUser>().WithOne().HasForeignKey<PlayerProfile>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}
