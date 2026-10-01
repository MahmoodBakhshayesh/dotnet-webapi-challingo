using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using System.Reflection.Emit;
using Challingo.Core.Domain.Entities;

namespace Challingo.Infrastructure.DbContexts.Configurations;

public sealed class OrganizationConfiguration : IEntityTypeConfiguration<Organization>
{
    public void Configure(EntityTypeBuilder<Organization> builder)
    {
        builder.ToTable("Organizations");
        builder.Property(x => x.Name).HasMaxLength(100).IsRequired();
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}
