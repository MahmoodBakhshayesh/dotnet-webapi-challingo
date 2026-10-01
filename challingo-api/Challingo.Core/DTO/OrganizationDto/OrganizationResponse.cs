namespace Challingo.Core.DTO.OrganizationDto
{
    public class OrganizationResponse
    {
        public Guid Id { get; set; }
        public required string Name { get; set; }
        public string? Description { get; set; }
    }
}
