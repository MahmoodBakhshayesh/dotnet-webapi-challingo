using System;
using System.Collections.Generic;
using System.Text;
using System.Text.Json.Serialization;

namespace Challingo.Core.Domain.Entities
{
    public class Organization: BaseEntity
    {
        public required string Name { get; set; }
        public string? Description { get; set; }
    }
}
