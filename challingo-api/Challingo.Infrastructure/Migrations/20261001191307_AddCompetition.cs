using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Challingo.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddCompetition : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "AnnouncedAtUtc",
                table: "Challenges",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "FinalizedAtUtc",
                table: "Challenges",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateOnly>(
                name: "LocalDate",
                table: "Challenges",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "PeriodKey",
                table: "Challenges",
                type: "character varying(16)",
                maxLength: 16,
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Sequence",
                table: "Challenges",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<string>(
                name: "SlotKey",
                table: "Challenges",
                type: "character varying(48)",
                maxLength: 48,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "WeekKey",
                table: "Challenges",
                type: "character varying(16)",
                maxLength: 16,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "CountryCode",
                table: "Attempts",
                type: "character varying(2)",
                maxLength: 2,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "CountsForDay",
                table: "Attempts",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "Points",
                table: "Attempts",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "Rank",
                table: "Attempts",
                type: "integer",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "RankScore",
                table: "Attempts",
                type: "double precision",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "Groups",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    InviteCode = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    OwnerUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    IsDeleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Groups", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "PeriodCloses",
                columns: table => new
                {
                    Key = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    ClosedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PeriodCloses", x => x.Key);
                });

            migrationBuilder.CreateTable(
                name: "StarTransactions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Amount = table.Column<int>(type: "integer", nullable: false),
                    RefKey = table.Column<string>(type: "character varying(96)", maxLength: 96, nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    IsDeleted = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_StarTransactions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_StarTransactions_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "GroupMembers",
                columns: table => new
                {
                    GroupId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    JoinedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GroupMembers", x => new { x.GroupId, x.UserId });
                    table.ForeignKey(
                        name: "FK_GroupMembers_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_GroupMembers_Groups_GroupId",
                        column: x => x.GroupId,
                        principalTable: "Groups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_ClosesAtUtc",
                table: "Challenges",
                column: "ClosesAtUtc",
                filter: "\"FinalizedAtUtc\" IS NULL AND \"SlotKey\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_Kind_PeriodKey",
                table: "Challenges",
                columns: new[] { "Kind", "PeriodKey" });

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_Kind_WeekKey",
                table: "Challenges",
                columns: new[] { "Kind", "WeekKey" });

            migrationBuilder.CreateIndex(
                name: "IX_Challenges_SlotKey",
                table: "Challenges",
                column: "SlotKey",
                unique: true,
                filter: "\"SlotKey\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_GroupMembers_UserId",
                table: "GroupMembers",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_Groups_InviteCode",
                table: "Groups",
                column: "InviteCode",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_StarTransactions_UserId_RefKey",
                table: "StarTransactions",
                columns: new[] { "UserId", "RefKey" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GroupMembers");

            migrationBuilder.DropTable(
                name: "PeriodCloses");

            migrationBuilder.DropTable(
                name: "StarTransactions");

            migrationBuilder.DropTable(
                name: "Groups");

            migrationBuilder.DropIndex(
                name: "IX_Challenges_ClosesAtUtc",
                table: "Challenges");

            migrationBuilder.DropIndex(
                name: "IX_Challenges_Kind_PeriodKey",
                table: "Challenges");

            migrationBuilder.DropIndex(
                name: "IX_Challenges_Kind_WeekKey",
                table: "Challenges");

            migrationBuilder.DropIndex(
                name: "IX_Challenges_SlotKey",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "AnnouncedAtUtc",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "FinalizedAtUtc",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "LocalDate",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "PeriodKey",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "Sequence",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "SlotKey",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "WeekKey",
                table: "Challenges");

            migrationBuilder.DropColumn(
                name: "CountryCode",
                table: "Attempts");

            migrationBuilder.DropColumn(
                name: "CountsForDay",
                table: "Attempts");

            migrationBuilder.DropColumn(
                name: "Points",
                table: "Attempts");

            migrationBuilder.DropColumn(
                name: "Rank",
                table: "Attempts");

            migrationBuilder.DropColumn(
                name: "RankScore",
                table: "Attempts");
        }
    }
}
