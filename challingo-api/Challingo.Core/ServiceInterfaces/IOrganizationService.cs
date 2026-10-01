using Microsoft.AspNetCore.Mvc;
using Challingo.Core.Domain.Entities;
using Challingo.Core.DTO.OrganizationDto;

namespace Challingo.Core.ServiceInterfaces
{
    public interface IOrganizationService
    {
        Task<ActionResult<List<OrganizationResponse>>> GetOrganizations();
        Task<ActionResult<OrganizationResponse>> GetOrganization(Guid id);
        Task<IActionResult> DeleteOrganization(Guid id);
        Task<ActionResult<Organization>> AddOrganization(AddOrganizationRequest request);
        Task<ActionResult<Organization>> UpdateOrganization(Guid id , UpdateOrganizationRequest request);
    }
}
