using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Challingo.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class GameRunsAndLottery : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Challenges_Kind_PeriodKey",
                table: "Challenges");

            migrationBuilder.DropIndex(
                name: "IX_Challenges_Kind_WeekKey",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "LocalDate",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "CountsForDay",
                table: "Attempts");

            migrationBuilder.AddColumn<string>(
                name: "GameKey",
                table: "Challenges",
                type: "character varying(32)",
                maxLength: 32,
                nullable: false,
                defaultValue: "");

            migrationBuilder.AddColumn<DateTime>(
                name: "JoinClosesAtUtc",
                table: "Challenges",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddColumn<string>(
                name: "MonthKey",
                table: "Challenges",
                type: "character varying(8)",
                maxLength: 8,
                nullable: true);

            // Existing challenges: copy the game from the puzzle; joining closed when the challenge closed.
            migrationBuilder.Sql("""
                UPDATE "Challenges" AS c SET "GameKey" = p."GameKey"
                FROM "Puzzles" AS p WHERE p."Id" = c."PuzzleId";
                UPDATE "Challenges" SET "JoinClosesAtUtc" = "ClosesAtUtc";
                UPDATE "Challenges" SET "MonthKey" = left("PeriodKey", 7) WHERE "PeriodKey" IS NOT NULL;
                """);

            migrationBuilder.CreateTable(
                name: "LotteryDraws",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    DayKey = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    Number = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    Salt = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    CommitHash = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    Pot = table.Column<int>(type: "integer", nullable: false),
                    AnnouncedDigits = table.Column<int>(type: "integer", nullable: false),
                    SettledAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    WinningMatch = table.Column<int>(type: "integer", nullable: true),
                    WinnerCount = table.Column<int>(type: "integer", nullable: true),
                    PrizePerWinner = table.Column<int>(type: "integer", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    IsDeleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LotteryDraws", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "LotteryTickets",
                columns: table => new
                {
                    DrawId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Number = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    PickedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LotteryTickets", x => new { x.DrawId, x.UserId });
                    table.ForeignKey(
                        name: "FK_LotteryTickets_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_LotteryTickets_LotteryDraws_DrawId",
                        column: x => x.DrawId,
                        principalTable: "LotteryDraws",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_Kind_GameKey_MonthKey",
                table: "Challenges",
                columns: new[] { "Kind", "GameKey", "MonthKey" });

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_Kind_GameKey_PeriodKey",
                table: "Challenges",
                columns: new[] { "Kind", "GameKey", "PeriodKey" });

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_Kind_GameKey_WeekKey",
                table: "Challenges",
                columns: new[] { "Kind", "GameKey", "WeekKey" });

            migrationBuilder.CreateIndex(
                name: "IX_LotteryDraws_DayKey",
                table: "LotteryDraws",
                column: "DayKey",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_LotteryTickets_DrawId_Number",
                table: "LotteryTickets",
                columns: new[] { "DrawId", "Number" })
                .Annotation("Npgsql:IndexOperators", new[] { "uuid_ops", "varchar_pattern_ops" });

            migrationBuilder.CreateIndex(
                name: "IX_LotteryTickets_UserId",
                table: "LotteryTickets",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "LotteryTickets");

            migrationBuilder.DropTable(
                name: "LotteryDraws");

            migrationBuilder.DropIndex(
                name: "IX_Challenges_Kind_GameKey_MonthKey",
                table: "Challenges");

            migrationBuilder.DropIndex(
                name: "IX_Challenges_Kind_GameKey_PeriodKey",
                table: "Challenges");

            migrationBuilder.DropIndex(
                name: "IX_Challenges_Kind_GameKey_WeekKey",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "GameKey",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "JoinClosesAtUtc",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "MonthKey",
                table: "Challenges");

            migrationBuilder.AddColumn<DateOnly>(
                name: "LocalDate",
                table: "Challenges",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "CountsForDay",
                table: "Attempts",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_Kind_PeriodKey",
                table: "Challenges",
                columns: new[] { "Kind", "PeriodKey" });

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_Kind_WeekKey",
                table: "Challenges",
                columns: new[] { "Kind", "WeekKey" });
        }
    }
}
