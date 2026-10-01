using Challingo.Core.Domain.IdentityEntities;

namespace Challingo.Core.Domain.Entities
{
    public class RefreshToken
    {
        public Guid Id { get; set; }
        public required Guid UserId { get; set; }
        public required string Token { get; set; }

        public required DateTime ExpireAtUtc { get; set; }

        public AppUser User { get; set; }

    }
}
