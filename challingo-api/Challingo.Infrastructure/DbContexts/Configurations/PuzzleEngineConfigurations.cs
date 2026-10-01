using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.IdentityEntities;

namespace Challingo.Infrastructure.DbContexts.Configurations;

public sealed class PuzzleConfiguration : IEntityTypeConfiguration<Puzzle>
{
    public void Configure(EntityTypeBuilder<Puzzle> builder)
    {
        builder.ToTable("Puzzles");
        builder.Property(x => x.GameKey).HasMaxLength(32).IsRequired();
        builder.Property(x => x.PublicJson).HasColumnType("jsonb").IsRequired();
        builder.Property(x => x.SecretJson).HasColumnType("jsonb").IsRequired();
        builder.HasIndex(x => x.GameKey);
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}

public sealed class ChallengeConfiguration : IEntityTypeConfiguration<Challenge>
{
    public void Configure(EntityTypeBuilder<Challenge> builder)
    {
        builder.ToTable("Challenges");
        builder.HasOne(x => x.Puzzle).WithMany().HasForeignKey(x => x.PuzzleId).OnDelete(DeleteBehavior.Restrict);
        builder.HasIndex(x => new { x.Kind, x.OpensAtUtc });
        builder.HasIndex(x => x.OwnerUserId);
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}

public sealed class AttemptConfiguration : IEntityTypeConfiguration<Attempt>
{
    public void Configure(EntityTypeBuilder<Attempt> builder)
    {
        builder.ToTable("Attempts");
        // One attempt per player per challenge, enforced by the database.
        builder.HasIndex(x => new { x.ChallengeId, x.UserId }).IsUnique();
        builder.HasIndex(x => x.UserId);
        builder.HasOne(x => x.Challenge).WithMany().HasForeignKey(x => x.ChallengeId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.Property(x => x.ResultJson).HasColumnType("jsonb");
        builder.Property(x => x.SubmissionJson).HasColumnType("jsonb");
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}
