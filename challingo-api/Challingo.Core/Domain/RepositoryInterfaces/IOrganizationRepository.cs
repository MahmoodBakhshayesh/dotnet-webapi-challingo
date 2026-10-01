using Microsoft.AspNetCore.Mvc;
using System;
using System.Collections.Generic;
using System.Text;
using Challingo.Core.Domain.Entities;
using Challingo.Core.DTO.OrganizationDto;

namespace Challingo.Core.Domain.RepositoryInterfaces
{
    public interface IOrganizationRepository
    {
        public Task<IEnumerable<Organization>> GetOrganizations();
        public Task<Organization?> GetOrganization(Guid id);
        public Task DeleteOrganizationById(Guid id);
        public Task<Organization?> AddOrganization(Organization organization);
        public Task<Organization?> UpdateOrganization(Organization organization);
    }
}
