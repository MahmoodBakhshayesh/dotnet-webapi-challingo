using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Challingo.Core.Domain.Entities;

namespace Challingo.Infrastructure.DbContexts.Configurations;

internal sealed class PhoneOtpChallengeConfiguration : IEntityTypeConfiguration<PhoneOtpChallenge>
{
    public void Configure(EntityTypeBuilder<PhoneOtpChallenge> builder)
    {
        builder.ToTable("PhoneOtpChallenges");
        builder.Property(x => x.PhoneNumber).HasMaxLength(256).IsRequired();
        builder.Property(x => x.CodeHash).HasMaxLength(256).IsRequired();
        builder.HasIndex(x => new { x.PhoneNumber, x.Status, x.ExpiresAtUtc });
        builder.HasOne(x => x.User)
            .WithMany()
            .HasForeignKey(x => x.UserId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
