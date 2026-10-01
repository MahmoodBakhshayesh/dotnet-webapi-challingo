using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using System;
using System.Collections.Generic;
using System.Text;
using Challingo.Core.Domain.Entities;

namespace Challingo.Infrastructure.DbContexts.Configurations
{
    internal class BaseEntityConfiguration : IEntityTypeConfiguration<BaseEntity>
    {
        public void Configure(EntityTypeBuilder<BaseEntity> builder)
        {
            builder.HasKey(x => x.Id);
            builder.Property(x => x.Id).HasMaxLength(500);
            builder.HasQueryFilter(x => !x.IsDeleted);
        }
    }
}

