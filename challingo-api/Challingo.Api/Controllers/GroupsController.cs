using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Challingo.Api.Extensions;
using Challingo.Core.DTO.Competition;
using Challingo.Core.ServiceInterfaces;

namespace Challingo.Api.Controllers;

/// <summary>Groups: create one, share its invite link, see everyone's results on the group board.</summary>
[Authorize]
public class GroupsController(IGroupService groups) : AppController
{
    [HttpGet]
    public async Task<ActionResult<List<GroupDto>>> List() =>
        User.GetUserId() is { } id ? await groups.ListAsync(id) : Unauthorized();

    [HttpPost]
    public async Task<ActionResult<GroupDto>> Create(CreateGroupRequest request) =>
        User.GetUserId() is { } id ? await groups.CreateAsync(id, request) : Unauthorized();

    [HttpGet("invite/{code}")]
    public async Task<ActionResult<GroupInviteDto>> Invite(string code) =>
        User.GetUserId() is { } id ? await groups.PreviewInviteAsync(id, code) : Unauthorized();

    [HttpPost("join")]
    public async Task<ActionResult<GroupDto>> Join(JoinGroupRequest request) =>
        User.GetUserId() is { } id ? await groups.JoinAsync(id, request) : Unauthorized();

    [HttpGet("{groupId:guid}")]
    public async Task<ActionResult<GroupDetailDto>> Get(Guid groupId) =>
        User.GetUserId() is { } id ? await groups.GetAsync(id, groupId) : Unauthorized();

    [HttpDelete("{groupId:guid}/membership")]
    public async Task<ActionResult> Leave(Guid groupId) =>
        User.GetUserId() is { } id ? await groups.LeaveAsync(id, groupId) : Unauthorized();
}
