using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Core.Domain.Entities;
using Challingo.Core.DTO.OrganizationDto;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Settings;

namespace Challingo.Api.Controllers
{
    [Authorize(Roles = Roles.Admin)]
    public class OrganizationsController(IOrganizationService organizationService) : AppController
    {
        [HttpGet]
        public async Task<ActionResult<List<OrganizationResponse>>> GetOrganizations()
        {
           return await organizationService.GetOrganizations();
        }

        [HttpGet("{id:guid}")]
        public async Task<ActionResult<OrganizationResponse>> GetOrganizations(Guid id)
        {
           return await organizationService.GetOrganization(id);
        }

        [HttpPost]
        public async Task<ActionResult<Organization>> AddOrganization(AddOrganizationRequest request)
        {
            return await organizationService.AddOrganization(request);
        }

        [HttpPut("{id:guid}")]
        public async Task<ActionResult<Organization>> UpdateOrganization(Guid id,UpdateOrganizationRequest request)
        {
            return await organizationService.UpdateOrganization(id,request);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> DeleteOrganization(Guid id)
        {
           return await organizationService.DeleteOrganization(id);
        }
    }
}
