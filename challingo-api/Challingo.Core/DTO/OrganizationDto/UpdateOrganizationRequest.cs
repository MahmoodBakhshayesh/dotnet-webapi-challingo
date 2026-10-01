
namespace Challingo.Core.DTO.OrganizationDto
{
    public class UpdateOrganizationRequest
    {
        public required string Name { set; get; }
        public string? Description { set; get; }
    }
}
