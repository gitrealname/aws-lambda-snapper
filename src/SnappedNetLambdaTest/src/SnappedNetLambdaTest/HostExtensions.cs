namespace Snapper.Runtime.Delegator
{
    using Microsoft.Extensions.Hosting;

    public static class HostExtensions
    {
        public static void SnapIt(this IHost? host, Action<bool>? afterRestore)
        {
            // check AWS_EXECUTION_ENV to see if restore endpoint is available; do nothing if not.
            var execEnv = Environment.GetEnvironmentVariable("AWS_EXECUTION_ENV");
            var apiUrl = Environment.GetEnvironmentVariable("AWS_LAMBDA_RUNTIME_API");
            if (string.IsNullOrWhiteSpace(execEnv) || string.IsNullOrWhiteSpace(apiUrl) || !execEnv.Contains("_java"))
            {
                Console.WriteLine("JVM-BRIDGE: AWS Execution environment has to to be Java for SnapIt to work.");
                return;
            }
            
            // see: https://docs.aws.amazon.com/lambda/latest/dg/runtimes-api.html
            // see: https://github.com/aws/aws-lambda-java-libs/blob/main/aws-lambda-java-runtime-interface-client/src/main/java/com/amazonaws/services/lambda/runtime/api/client/runtimeapi/LambdaRuntimeApiClientImpl.java
            // see: https://docs.aws.amazon.com/lambda/latest/dg/samples/runtime-api.zip


            //NOTE: having this call in the thread, which waits for core to finish bootstrapping, has failed.
            var success = true;
                using var client = new HttpClient();
                client.BaseAddress = new Uri( $"http://{apiUrl}");
                var response = client.GetAsync("2018-06-01/runtime/restore/next").GetAwaiter().GetResult();
                if (!response.IsSuccessStatusCode)
                {
                    Console.Error.WriteLine($"JVM-BRIDGE: restore/net has failed. Continue as if nothing happened.");
                    success = false;
                }
                Console.WriteLine($"JVM-BRIDGE: RESTORED; status: {success}");

                if(afterRestore != null) {
                    afterRestore(success);
                }
        }
    }
}