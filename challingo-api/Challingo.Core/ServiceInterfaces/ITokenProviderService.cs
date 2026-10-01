using Challingo.Core.DTO.Token;

namespace Challingo.Core.ServiceInterfaces
{
    public interface ITokenProviderService
    {
        public TokenResponse Create(TokenRequest tokenRequest);

    }
}
