using Challingo.Core.Domain.Entities;

namespace Challingo.Core.DTO.OrganizationDto
{
    public static class OrganizationMappers
    {
        public static OrganizationResponse ToResponse(this Organization organization)
        {
            return new OrganizationResponse
            {
                Id = organization.Id,
                Name = organization.Name,
                Description = organization.Description,
            };
        }

        public static Organization ToEntity(this AddOrganizationRequest addOrganizationRequest)
        {
            return new Organization { Id = Guid.CreateVersion7(), Name = addOrganizationRequest.Name };
        }

        public static Organization UpdateWithRequest(this Organization organization , UpdateOrganizationRequest updateRequest)
        {
            organization.Name = updateRequest.Name;
            organization.Description = updateRequest.Description;
            return organization;
        }


    }
}
