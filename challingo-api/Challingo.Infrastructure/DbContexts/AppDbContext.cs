using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.IdentityEntities;
using Challingo.Infrastructure.DbContexts.Configurations;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Text;

namespace Challingo.Infrastructure.DbContexts
{
    public class AppDbContext : IdentityDbContext<AppUser,AppRole,Guid,IdentityUserClaim<Guid>,AppUserRole,IdentityUserLogin<Guid>,IdentityRoleClaim<Guid>,IdentityUserToken<Guid>>
    {
        public AppDbContext (DbContextOptions options): base(options)
        {

        }

        public DbSet<Organization> Organizations { set; get; }
        public DbSet<RefreshToken> RefreshTokens { set; get; }
        public DbSet<PhoneOtpChallenge> PhoneOtpChallenges { set; get; }
        public DbSet<PlayerProfile> PlayerProfiles { set; get; }
        public DbSet<Puzzle> Puzzles { set; get; }
        public DbSet<Challenge> Challenges { set; get; }
        public DbSet<Attempt> Attempts { set; get; }
        public DbSet<PuzzleContent> PuzzleContents { set; get; }
        public DbSet<StarTransaction> StarTransactions { set; get; }
        public DbSet<PeriodClose> PeriodCloses { set; get; }
        public DbSet<Group> Groups { set; get; }
        public DbSet<GroupMember> GroupMembers { set; get; }
        public DbSet<LotteryDraw> LotteryDraws { set; get; }
        public DbSet<LotteryTicket> LotteryTickets { set; get; }
        public DbSet<AdReward> AdRewards { set; get; }
        public DbSet<PlusEntitlement> PlusEntitlements { set; get; }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);
            // Must run after base: maps AppUserRole.User/Role navigations onto the existing
            // UserId/RoleId FKs (otherwise EF adds shadow UserId1/RoleId1 columns).
            builder.ApplyConfiguration(new Configurations.AppUserRoleConfiguration());
            builder.ApplyConfiguration(new Configurations.PhoneOtpChallengeConfiguration());
            builder.ApplyConfiguration(new Configurations.OrganizationConfiguration());
            builder.ApplyConfiguration(new Configurations.PlayerProfileConfiguration());
            builder.ApplyConfiguration(new Configurations.PuzzleConfiguration());
            builder.ApplyConfiguration(new Configurations.ChallengeConfiguration());
            builder.ApplyConfiguration(new Configurations.AttemptConfiguration());
            builder.ApplyConfiguration(new Configurations.PuzzleContentConfiguration());
            builder.ApplyConfiguration(new Configurations.StarTransactionConfiguration());
            builder.ApplyConfiguration(new Configurations.PeriodCloseConfiguration());
            builder.ApplyConfiguration(new Configurations.GroupConfiguration());
            builder.ApplyConfiguration(new Configurations.GroupMemberConfiguration());
            builder.ApplyConfiguration(new Configurations.LotteryDrawConfiguration());
            builder.ApplyConfiguration(new Configurations.LotteryTicketConfiguration());
            builder.ApplyConfiguration(new Configurations.AdRewardConfiguration());
            builder.ApplyConfiguration(new Configurations.PlusEntitlementConfiguration());
        }

        public override int SaveChanges() =>
            SaveChangesAsync().GetAwaiter().GetResult();

        public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
        {
            ApplyAuditAndSoftDelete();
            return base.SaveChangesAsync(cancellationToken);
        }

        private void ApplyAuditAndSoftDelete()
        {
            var now = DateTime.UtcNow;
            foreach (var entry in ChangeTracker.Entries<BaseEntity>())
            {
                switch (entry.State)
                {
                    case EntityState.Added:
                        entry.Entity.CreatedAt = now;
                        entry.Entity.UpdatedAt = null;
                        break;
                    case EntityState.Modified:
                        entry.Entity.UpdatedAt = now;
                        break;
                    case EntityState.Deleted:
                        entry.State = EntityState.Modified;
                        entry.Entity.IsDeleted = true;
                        entry.Entity.UpdatedAt = now;
                        break;
                }
            }
        }
    }
}

