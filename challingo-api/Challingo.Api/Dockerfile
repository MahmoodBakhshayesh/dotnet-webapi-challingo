# Build context: api/ folder (repository root for API projects).
# docker build -f Challingo.Api/Dockerfile .

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY Challingo.Api/Challingo.Api.csproj Challingo.Api/
COPY Challingo.Core/Challingo.Core.csproj Challingo.Core/
COPY Challingo.Infrastructure/Challingo.Infrastructure.csproj Challingo.Infrastructure/

RUN dotnet restore Challingo.Api/Challingo.Api.csproj

COPY Challingo.Api/ Challingo.Api/
COPY Challingo.Core/ Challingo.Core/
COPY Challingo.Infrastructure/ Challingo.Infrastructure/

RUN dotnet publish Challingo.Api/Challingo.Api.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
RUN mkdir -p /app/wwwroot/uploads/avatars \
    && chown -R "${APP_UID:-1654}" /app/wwwroot \
    && apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=40s --retries=5 \
  CMD curl -fsS http://127.0.0.1:8080/health/ready || exit 1
ENTRYPOINT ["dotnet", "Challingo.Api.dll"]
