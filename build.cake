///////////////////////////////////////////////////////////////////////////////
// ARGUMENTS
///////////////////////////////////////////////////////////////////////////////

var target = Argument("target", "Default");
var configuration = Argument("configuration", "Release");

Task("Client")
    .Does(() =>
{
    if (FileExists("wwwroot/js/elm.js")) DeleteFile("wwwroot/js/elm.js");
    var exitCodeWithArgument = StartProcess("elm", new ProcessSettings{ Arguments = "make src/Main.elm --optimize --output=wwwroot/js/elm.js" });
    // This should output 0 as valid arguments supplied
    if (exitCodeWithArgument != 0) throw new Exception("Elm failed");
    Information("Exit code: {0}", exitCodeWithArgument);
});

Task("Server")
    .Does(() => 
{
    DotNetCoreBuild("./voute-ask.csproj");
});

Task("Run")
    .Does(() => 
{
    DotNetCoreRun("./voute-ask.csproj");
});

///////////////////////////////////////////////////////////////////////////////
// TASKS
///////////////////////////////////////////////////////////////////////////////

Task("Default")
    .IsDependentOn("Client")
    .IsDependentOn("Server")
    .IsDependentOn("Run");

RunTarget(target);