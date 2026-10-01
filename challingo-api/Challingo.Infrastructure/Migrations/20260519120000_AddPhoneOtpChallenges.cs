using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Challingo.Infrastructure.Migrations
{
    public partial class AddPhoneOtpChallenges : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PhoneOtpChallenges",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    PhoneNumber = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    CodeHash = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    ExpiresAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    AttemptCount = table.Column<int>(type: "integer", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    VerifiedAtUtc = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PhoneOtpChallenges", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PhoneOtpChallenges_AspNetUsers_UserId",
                        column: x => x.UserId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PhoneOtpChallenges_PhoneNumber_Status_ExpiresAtUtc",
                table: "PhoneOtpChallenges",
                columns: new[] { "PhoneNumber", "Status", "ExpiresAtUtc" });

            migrationBuilder.CreateIndex(
                name: "IX_PhoneOtpChallenges_UserId",
                table: "PhoneOtpChallenges",
                column: "UserId");
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(name: "PhoneOtpChallenges");
        }
    }
}
