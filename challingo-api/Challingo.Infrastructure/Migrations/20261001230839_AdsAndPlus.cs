using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Challingo.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AdsAndPlus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "AdRewards",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    DayKey = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    TransactionId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    AdUnit = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: false),
                    RewardedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AdRewards", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AdRewards_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlusEntitlements",
                columns: table => new
                {
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    Active = table.Column<bool>(type: "boolean", nullable: false),
                    ProductId = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    Store = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: true),
                    UpdatedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlusEntitlements", x => x.UserId);
                    table.ForeignKey(
                        name: "FK_PlusEntitlements_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_AdRewards_TransactionId",
                table: "AdRewards",
                column: "TransactionId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AdRewards_UserId_DayKey",
                table: "AdRewards",
                columns: new[] { "UserId", "DayKey" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AdRewards");

            migrationBuilder.DropTable(
                name: "PlusEntitlements");
        }
    }
}
