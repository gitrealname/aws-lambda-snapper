using System.Text.Json;
using Amazon.Lambda.AspNetCoreServer;
using Microsoft.AspNetCore.Hosting.Server;

Console.WriteLine($"SnappedAspLambdaTest: ENTERY POINT");

var builder = WebApplication.CreateBuilder(args);

// Add AWS Lambda support. When application is run in Lambda Kestrel is swapped out as the web server with Amazon.Lambda.AspNetCoreServer. This
// package will act as the webserver translating request and responses between the Lambda event source and ASP.NET Core.
builder.Services.AddAWSLambdaHosting(LambdaEventSource.HttpApi);

// Add services to the container.
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.AddControllers();

builder.Logging
    .AddConsole()
    .AddDebug();

builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.PropertyNameCaseInsensitive = true;
    o.SerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    o.SerializerOptions.DictionaryKeyPolicy = JsonNamingPolicy.CamelCase;
});


var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger(o =>
    {
    });
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();

app.MapControllers();

app.UseDefaultFiles();


app.MapGet("/test", () => "{test: true}");

Console.WriteLine($"SnappedAspLambdaTest: ABOUT TO RUN");
app.Run();
