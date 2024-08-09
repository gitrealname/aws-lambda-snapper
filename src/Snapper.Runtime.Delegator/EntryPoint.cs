namespace Snapper.Runtime.Delegator
{
    using System.Reflection;
    using Amazon.Lambda.RuntimeSupport;
    using System.Runtime.InteropServices;
    using System.Runtime.Loader;
    using System.Net;

    static class EntryPoint
    {
        private static string AWS_RUNTIME_ASSEMBLY = "Amazon.Lambda.RuntimeSupport";
        private static string LAMBDA_HANDLER_ENV = "_HANDLER";
        private static string LAMBDA_ROOT_ENV = "LAMBDA_TASK_ROOT";

        //important: expected to be set by snapper
        private static string NET_RUNTIME_PATH_ENV = "NET_RUNTIME_PATH";

        [StructLayout(LayoutKind.Sequential)]
        public struct LibArgs
        {
        }

        private static string? _handlerRoot;
        private static string? _frameworkRoot;

        private static Dictionary<string, Assembly> _assemblyCache = new Dictionary<string, Assembly>();

        [UnmanagedCallersOnly]
        public static void StartUnmanagedOnly(LibArgs libArgs)
        {
            var appDomain = AppDomain.CurrentDomain;
            var runtimeAssemblyName = new AssemblyName(AWS_RUNTIME_ASSEMBLY);
            var handlerName = Environment.GetEnvironmentVariable(LAMBDA_HANDLER_ENV);

            //override assembly loading logic
            _handlerRoot = Environment.GetEnvironmentVariable(LAMBDA_ROOT_ENV);
            _frameworkRoot = Environment.GetEnvironmentVariable(NET_RUNTIME_PATH_ENV);
            appDomain.AssemblyResolve += ResolveAssembly;
            appDomain.ReflectionOnlyAssemblyResolve += ResolveAssembly;

            //runtime assembly is expected to reside in .NET runtime directory; same location as this assembly
            //var runtime = AssemblyLoadContext.Default.LoadFromAssemblyName(runtimeAssemblyName);

            //pre-heat cache with already loaded assemblies
            var loaddedAssemblies = appDomain.GetAssemblies();
            foreach(var a in loaddedAssemblies) {
                var pureName = GetAsseblyPureName(a.FullName ?? "disable-warning");
                _assemblyCache.Add(pureName, a);
                //Console.WriteLine($"RUNTIME-DELEGATOR: already loaded assembly: {pureName}");
            }

            //insure that Core assembly is loaded and not optimized
            var coreRef = Amazon.Lambda.Core.LogLevel.Critical;
            Nop(coreRef);

            //while bootstrapping, we don't cache DNS resolves
            ServicePointManager.DnsRefreshTimeout = 0;
            
            //start runtime
            RuntimeSupportInitializer runtimeSupportInitializer = new RuntimeSupportInitializer(handlerName);
            runtimeSupportInitializer.RunLambdaBootstrap().GetAwaiter().GetResult();
        }

        private static void Nop(object ignore) {

        }

        private static string GetAsseblyPureName(string fullName)
        {
            var pureName = fullName.Split(',')[0];
            return pureName;
        }

        private static Assembly? ResolveAssembly(Object? sender, ResolveEventArgs e) 
        {
            var pureName = GetAsseblyPureName(e.Name);

            //check in cache first
            if(_assemblyCache.TryGetValue(pureName, out var ass)) {
                return ass;
            }

            var fn1 = $"{_frameworkRoot}/{pureName}.dll";
            var fn2 = $"{_handlerRoot}/{pureName}.dll";
            
            if (File.Exists(fn1))
            {
                var a = Assembly.LoadFile(fn1);
                _assemblyCache.Add(pureName, a);
                //Console.WriteLine($"RUNTIME-DELEGATOR: loaded assembly: {fn1}");
                return a;
            }
            else if (File.Exists(fn2)) 
            {
                var a = Assembly.LoadFile(fn2);
                _assemblyCache.Add(pureName, a);
                //Console.WriteLine($"RUNTIME-DELEGATOR: loaded assembly: {fn2}");
                return a;
            }
            else
            {
                //Console.Error.WriteLine($"RUNTIME-DELEGATOR: Unable to find assembly: {pureName}; file name: {fn1} nor {fn2} ");
            }
            return null;
        }
    }
}
