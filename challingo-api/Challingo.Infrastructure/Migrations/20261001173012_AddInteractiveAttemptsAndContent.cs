using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Challingo.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddInteractiveAttemptsAndContent : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "IncorrectSubmissions",
                table: "Attempts",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "MoveCount",
                table: "Attempts",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "StateJson",
                table: "Attempts",
                type: "text",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "PuzzleContents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    GameKey = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    ContentKey = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    PayloadJson = table.Column<string>(type: "jsonb", nullable: false),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    ReviewedByUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    ReviewedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    IsDeleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PuzzleContents", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PuzzleContents_GameKey_ContentKey",
                table: "PuzzleContents",
                columns: new[] { "GameKey", "ContentKey" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PuzzleContents_GameKey_Status",
                table: "PuzzleContents",
                columns: new[] { "GameKey", "Status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PuzzleContents");

            migrationBuilder.DropColumn(
                name: "IncorrectSubmissions",
                table: "Attempts");

            migrationBuilder.DropColumn(
                name: "MoveCount",
                table: "Attempts");

            migrationBuilder.DropColumn(
                name: "StateJson",
                table: "Attempts");
        }
    }
}
