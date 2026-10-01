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
        builder.Property(x => x.GameKey).HasMaxLength(32).IsRequired();
        builder.Property(x => x.SlotKey).HasMaxLength(48);
        builder.Property(x => x.PeriodKey).HasMaxLength(16);
        builder.Property(x => x.WeekKey).HasMaxLength(16);
        builder.Property(x => x.MonthKey).HasMaxLength(8);
        builder.HasIndex(x => x.SlotKey).IsUnique().HasFilter("\"SlotKey\" IS NOT NULL");
        builder.HasIndex(x => new { x.Kind, x.GameKey, x.PeriodKey });
        builder.HasIndex(x => new { x.Kind, x.GameKey, x.WeekKey });
        builder.HasIndex(x => new { x.Kind, x.GameKey, x.MonthKey });
        builder.HasIndex(x => x.ClosesAtUtc).HasFilter("\"FinalizedAtUtc\" IS NULL AND \"SlotKey\" IS NOT NULL");
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
        builder.Property(x => x.CountryCode).HasMaxLength(2);
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}

public sealed class LotteryDrawConfiguration : IEntityTypeConfiguration<LotteryDraw>
{
    public void Configure(EntityTypeBuilder<LotteryDraw> builder)
    {
        builder.ToTable("LotteryDraws");
        builder.Property(x => x.DayKey).HasMaxLength(10).IsRequired();
        builder.HasIndex(x => x.DayKey).IsUnique();
        builder.Property(x => x.Number).HasMaxLength(10).IsRequired();
        builder.Property(x => x.Salt).HasMaxLength(64).IsRequired();
        builder.Property(x => x.CommitHash).HasMaxLength(64).IsRequired();
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}

public sealed class LotteryTicketConfiguration : IEntityTypeConfiguration<LotteryTicket>
{
    public void Configure(EntityTypeBuilder<LotteryTicket> builder)
    {
        builder.ToTable("LotteryTickets");
        builder.HasKey(x => new { x.DrawId, x.UserId });
        builder.Property(x => x.Number).HasMaxLength(10).IsRequired();
        // Prefix matching ("still alive", winners) uses LIKE 'prefix%'.
        builder.HasIndex(x => new { x.DrawId, x.Number }).HasOperators("uuid_ops", "varchar_pattern_ops");
        builder.HasOne<LotteryDraw>().WithMany().HasForeignKey(x => x.DrawId).OnDelete(DeleteBehavior.Cascade);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class AdRewardConfiguration : IEntityTypeConfiguration<AdReward>
{
    public void Configure(EntityTypeBuilder<AdReward> builder)
    {
        builder.ToTable("AdRewards");
        builder.Property(x => x.DayKey).HasMaxLength(10).IsRequired();
        builder.Property(x => x.TransactionId).HasMaxLength(128).IsRequired();
        builder.Property(x => x.AdUnit).HasMaxLength(128);
        builder.HasIndex(x => x.TransactionId).IsUnique();
        builder.HasIndex(x => new { x.UserId, x.DayKey });
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class PlusEntitlementConfiguration : IEntityTypeConfiguration<PlusEntitlement>
{
    public void Configure(EntityTypeBuilder<PlusEntitlement> builder)
    {
        builder.ToTable("PlusEntitlements");
        builder.HasKey(x => x.UserId);
        builder.Property(x => x.ProductId).HasMaxLength(128);
        builder.Property(x => x.Store).HasMaxLength(32);
        builder.HasOne<AppUser>().WithOne().HasForeignKey<PlusEntitlement>(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}

public sealed class StarTransactionConfiguration : IEntityTypeConfiguration<StarTransaction>
{
    public void Configure(EntityTypeBuilder<StarTransaction> builder)
    {
        builder.ToTable("StarTransactions");
        builder.Property(x => x.RefKey).HasMaxLength(96).IsRequired();
        // Each award is paid once.
        builder.HasIndex(x => new { x.UserId, x.RefKey }).IsUnique();
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}

public sealed class PeriodCloseConfiguration : IEntityTypeConfiguration<PeriodClose>
{
    public void Configure(EntityTypeBuilder<PeriodClose> builder)
    {
        builder.ToTable("PeriodCloses");
        builder.HasKey(x => x.Key);
        builder.Property(x => x.Key).HasMaxLength(32);
    }
}

public sealed class GroupConfiguration : IEntityTypeConfiguration<Group>
{
    public void Configure(EntityTypeBuilder<Group> builder)
    {
        builder.ToTable("Groups");
        builder.Property(x => x.Name).HasMaxLength(30).IsRequired();
        builder.Property(x => x.InviteCode).HasMaxLength(16).IsRequired();
        builder.HasIndex(x => x.InviteCode).IsUnique();
        builder.HasMany(x => x.Members).WithOne().HasForeignKey(m => m.GroupId).OnDelete(DeleteBehavior.Cascade);
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}

public sealed class GroupMemberConfiguration : IEntityTypeConfiguration<GroupMember>
{
    public void Configure(EntityTypeBuilder<GroupMember> builder)
    {
        builder.ToTable("GroupMembers");
        builder.HasKey(x => new { x.GroupId, x.UserId });
        builder.HasIndex(x => x.UserId);
        builder.HasOne<AppUser>().WithMany().HasForeignKey(x => x.UserId).OnDelete(DeleteBehavior.Cascade);
    }
}
