using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Challingo.Core.Domain.RepositoryInterfaces;
using Challingo.Core.Puzzles;
using Challingo.Core.Puzzles.Content;
using Challingo.Core.Puzzles.Games.CodeBreaker;
using Challingo.Core.Puzzles.Games.Kakuro;
using Challingo.Core.Puzzles.Games.MineLogic;
using Challingo.Core.Puzzles.Games.MiniCrossword;
using Challingo.Core.Puzzles.Games.Nonogram;
using Challingo.Core.Puzzles.Games.NumberMerge;
using Challingo.Core.Puzzles.Games.PathLink;
using Challingo.Core.Puzzles.Games.Sudoku;
using Challingo.Core.Puzzles.Games.WordGuess;
using Challingo.Core.Puzzles.Games.WordHunt;
using Challingo.Core.Puzzles.Words;
using Challingo.Core.ServiceInterfaces;
using Challingo.Core.Services;
using Challingo.Core.Settings;
using Challingo.Infrastructure.Repositories;
using Challingo.Infrastructure.Words;

namespace Challingo.Infrastructure;

/// <summary>Game engine and competition services, shared by the API and the Worker.</summary>
public static class ChallingoServiceCollectionExtensions
{
    /// <param name="contentRoot">Base for a relative <c>Words:DictionaryPath</c>.</param>
    public static IServiceCollection AddChallingoGameEngine(this IServiceCollection services, string contentRoot)
    {
        services.TryAddSingleton(TimeProvider.System);
        services.AddTransient<IPlayerProfileRepository, PlayerProfileRepository>();

        // One IPuzzleGame per minigame, looked up by key. Generated games are singletons;
        // games built from reviewed content (and so the registry) are scoped to the DbContext.
        services.AddOptions<PuzzleOptions>().BindConfiguration("Puzzles");
        services.AddOptions<WordsOptions>().BindConfiguration("Words");
        services.AddSingleton<IWordDictionary>(sp =>
        {
            var path = sp.GetRequiredService<IOptions<WordsOptions>>().Value.DictionaryPath;
            var fullPath = Path.IsPathRooted(path) ? path : Path.Combine(contentRoot, path);
            return FileWordDictionary.Load(fullPath, sp.GetRequiredService<ILoggerFactory>().CreateLogger("Words"));
        });
        services.AddSingleton<IPuzzleGame, SudokuGame>();
        services.AddSingleton<IPuzzleGame, PathLinkGame>();
        services.AddSingleton<IPuzzleGame, KakuroGame>();
        services.AddSingleton<IPuzzleGame, NonogramGame>();
        services.AddSingleton<IPuzzleGame, MineLogicGame>();
        services.AddSingleton<IPuzzleGame, CodeBreakerGame>();
        services.AddSingleton<IPuzzleGame, NumberMergeGame>();
        services.AddSingleton<IPuzzleGame, WordHuntGame>();
        services.AddScoped<IPuzzleGame, WordGuessGame>();
        services.AddScoped<IPuzzleGame, MiniCrosswordGame>();
        services.AddScoped<IPuzzleGameRegistry, PuzzleGameRegistry>();
        services.AddSingleton<IPuzzleContentValidator, WordGuessContentValidator>();
        services.AddSingleton<IPuzzleContentValidator, MiniCrosswordContentValidator>();
        services.AddTransient<IPuzzleContentRepository, PuzzleContentRepository>();
        return services;
    }

    /// <summary>Schedule, scoring, boards, stars and groups. Needs ILeaderboardStore and IRealtimeNotifier.</summary>
    public static IServiceCollection AddChallingoCompetition(this IServiceCollection services)
    {
        services.AddOptions<CompetitionOptions>().BindConfiguration("Competition");
        services.AddTransient<ICompetitionRepository, CompetitionRepository>();
        services.AddTransient<IGroupRepository, GroupRepository>();
        services.AddTransient<ILotteryRepository, LotteryRepository>();
        services.AddTransient<ILotteryService, LotteryService>();
        services.AddTransient<ICompetitionService, CompetitionService>();
        services.AddTransient<ICompetitionScheduler, CompetitionScheduler>();
        services.AddTransient<ICompetitionCloser, CompetitionCloser>();
        services.AddTransient<IScheduleAdminService, ScheduleAdminService>();
        services.AddTransient<IGroupService, GroupService>();
        return services;
    }
}
