using Challingo.Core.Domain.IdentityEntities;

namespace Challingo.Core.DTO.UserDto
{
    public static class UserMappers
    {
        public static UserResponse ToResponse(this AppUser user)
        {
            return new UserResponse { Id = user.Id , UserName = user.UserName!, Email = user.Email , PhoneNumber = user.PhoneNumber};
        }
    }
}
