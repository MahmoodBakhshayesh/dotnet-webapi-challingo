# Build context: challingo-api folder (same as API Dockerfile parent).
# docker build -f Challingo.Worker/Dockerfile .

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY Challingo.Core/Challingo.Core.csproj Challingo.Core/
COPY Challingo.Infrastructure/Challingo.Infrastructure.csproj Challingo.Infrastructure/
COPY Challingo.Worker/Challingo.Worker.csproj Challingo.Worker/

RUN dotnet restore Challingo.Worker/Challingo.Worker.csproj

COPY Challingo.Core/ Challingo.Core/
COPY Challingo.Infrastructure/ Challingo.Infrastructure/
COPY Challingo.Worker/ Challingo.Worker/

RUN dotnet publish Challingo.Worker/Challingo.Worker.csproj -c Release -o /app/publish

# Core/Infrastructure reference Microsoft.AspNetCore.* — needs aspnet runtime (same as API), not runtime-only.
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENV DOTNET_ENVIRONMENT=Production
# No HTTP endpoint — process liveness (PID 1 = worker entrypoint).
HEALTHCHECK --interval=15s --timeout=5s --start-period=40s --retries=5 \
  CMD kill -0 1 || exit 1
ENTRYPOINT ["dotnet", "Challingo.Worker.dll"]
