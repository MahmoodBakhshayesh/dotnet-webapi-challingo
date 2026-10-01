using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.OrganizationDto;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Core.Services
{
    public class OrganizationService(IOrganizationRepository organizationsRepository) : IOrganizationService
    {


        async Task<ActionResult<List<OrganizationResponse>>> IOrganizationService.GetOrganizations()
        {
            var orgs = await organizationsRepository.GetOrganizations();
            return AppResponse.OkList(orgs.Select(o => o.ToResponse()));
        }

        async Task<ActionResult<Organization>> IOrganizationService.AddOrganization(AddOrganizationRequest request)
        {
            var org = await organizationsRepository.AddOrganization(request.ToEntity());
            if (org == null)
            {
                ProblemDetails problemDetails = new ProblemDetails();
                return AppResponse.RequestError(problemDetails);
            }
            return AppResponse.Ok(org);
        }

        public async Task<ActionResult<Organization>> UpdateOrganization(Guid id, UpdateOrganizationRequest request)
        {
            var old = await organizationsRepository.GetOrganization(id);
            if (old == null)
            {
                return AppResponse.NotFound();
            }
            var updated = old.UpdateWithRequest(request);
            var org =   await organizationsRepository.UpdateOrganization(updated);
            return AppResponse.Ok(org);
        }

        public async Task<ActionResult<OrganizationResponse>> GetOrganization(Guid id)
        {
            var org = await organizationsRepository.GetOrganization(id);
            if (org == null)
            {
                return AppResponse.NotFound(); 
            }

            return AppResponse.Ok(org.ToResponse());
        }

        public async Task<IActionResult> DeleteOrganization(Guid id)
        {
            await organizationsRepository.DeleteOrganizationById(id);
            return AppResponse.Ok(statusCode:StatusCodes.Status204NoContent);
        }
    }
}
