using System;
using System.Collections.Generic;
using System.Text;
using Challingo.Core.DTO.Token;

namespace Challingo.Core.Domain.RepositoryInterfaces
{
    public interface ITokenProviderRepository
    {
        public TokenResponse Create(TokenRequest tokenRequest);
    }
}
