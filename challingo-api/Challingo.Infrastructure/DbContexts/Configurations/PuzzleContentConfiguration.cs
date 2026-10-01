using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Challingo.Core.Domain.Entities;

namespace Challingo.Infrastructure.DbContexts.Configurations;

public sealed class PuzzleContentConfiguration : IEntityTypeConfiguration<PuzzleContent>
{
    public void Configure(EntityTypeBuilder<PuzzleContent> builder)
    {
        builder.ToTable("PuzzleContents");
        builder.Property(x => x.GameKey).HasMaxLength(32).IsRequired();
        builder.Property(x => x.ContentKey).HasMaxLength(128).IsRequired();
        builder.Property(x => x.PayloadJson).HasColumnType("jsonb").IsRequired();
        builder.Property(x => x.Notes).HasMaxLength(500);
        builder.HasIndex(x => new { x.GameKey, x.ContentKey }).IsUnique();
        builder.HasIndex(x => new { x.GameKey, x.Status });
        builder.HasQueryFilter(x => !x.IsDeleted);
    }
}
