using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Text;
using Challingo.Infrastructure.DbContexts;
using Challingo.Core.Domain.Entities;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.DTO.OrganizationDto;

namespace Challingo.Infrastructure.Repositories
{
    public class OrganizationsRepository(AppDbContext dbContext) : IOrganizationRepository
    {


        async Task<IEnumerable<Organization>> IOrganizationRepository.GetOrganizations()
        {
            var organizations =await dbContext.Organizations.ToListAsync();
            return organizations;
        }

        public async Task<Organization?> AddOrganization(Organization organization)
        {
            dbContext.Organizations.Add(organization);
            await dbContext.SaveChangesAsync();
            return organization;
        }

        public async Task<Organization> UpdateOrganization(Organization update)
        {
            dbContext.Organizations.Update(update);
            await dbContext.SaveChangesAsync();
            return update;
        }

        public async Task<Organization?> GetOrganization(Guid id)
        {
            Organization? organization = await dbContext.Organizations.FirstOrDefaultAsync(o => o.Id == id);
            if(organization == null)
            {
                return null;
            }
            return organization;
        }

        public async Task DeleteOrganizationById(Guid id)
        {
            var org = await dbContext.Organizations.FirstOrDefaultAsync(o => o.Id == id);
            dbContext.Organizations.Remove(org!);
            await dbContext.SaveChangesAsync();
        }
    }
}
