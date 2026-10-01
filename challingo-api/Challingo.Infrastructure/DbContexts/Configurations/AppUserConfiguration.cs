using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using System;
using System.Collections.Generic;
using System.Text;
using Challingo.Core.Domain.IdentityEntities;

namespace Challingo.Infrastructure.DbContexts.Configurations
{
    internal class AppUserConfiguration : IEntityTypeConfiguration<AppUser>
    {
        public void Configure(EntityTypeBuilder<AppUser> builder)
        {
            builder.HasKey(x=> x.Id);
            builder.Property(u=>u.UserName).IsRequired();
            builder.HasMany(u => u.UserRoles)
             .WithOne(ur => ur.User)
             .HasForeignKey(ur => ur.UserId).IsRequired();
        }
    }
}
