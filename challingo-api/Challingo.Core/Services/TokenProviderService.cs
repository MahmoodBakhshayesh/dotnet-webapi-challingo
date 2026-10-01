using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.Token;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Core.Services
{
    public class TokenProviderService(ITokenProviderRepository tokenRepository) : ITokenProviderService
    {
        public TokenResponse Create(TokenRequest tokenRequest)
        {
            var token = tokenRepository.Create(tokenRequest);
            return token;
        }
    }
}
