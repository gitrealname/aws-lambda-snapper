// Assembly attribute to enable the Lambda function's JSON input to be converted into a .NET class.

using Amazon.Lambda.Core;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace SnappedNetLambdaTest
{

    using System.Text.Json;
    using Amazon.Lambda.APIGatewayEvents;
    using Amazon.Lambda.Core;
    using Snapper.Runtime.Delegator;

    public class Function
    {
        private readonly string _initTime;
        private readonly byte[] _data;

        public Function()
        {
            Console.WriteLine("--------------------< Bootstrapping... >------------------------");
            Task.Delay(5 * 1000).GetAwaiter().GetResult();
            _initTime = DateTime.Now.ToString("g");
            //simulate memory use.
            _data = new byte[50 * 1024 * 1024];
            Console.WriteLine("--------------------< Bootstrapping is done. >------------------------");
            
            //The following works, BUT!!!! we loose about 2 seconds during restore, which are needed for CORE 
            //to get it's bootstrapping fully done.
            //By other words it takes ~2 seconds from this place to first call to '...runtime/next call!
            // Feel free to uncomment to test/see the diff.
            // ((IHost?)null).SnapIt((restoredSuccess) =>
            // {
            //     Console.WriteLine($"FUNCTION: restore point result: {restoredSuccess}");
            // });
        }

        private static readonly HttpClient client = new HttpClient();

        private static async Task<string> GetCallingIP()
        {
            client.DefaultRequestHeaders.Accept.Clear();
            client.DefaultRequestHeaders.Add("User-Agent", "AWS Lambda .Net Client");

            var msg = await client.GetStringAsync("http://checkip.amazonaws.com/").ConfigureAwait(continueOnCapturedContext:false);

            return msg.Replace("\n","");
        }

        public async Task<APIGatewayProxyResponse> FunctionHandler(APIGatewayProxyRequest apigProxyEvent, ILambdaContext context)
        {

            Console.WriteLine($"-------< Processing request....(init time: {_initTime}) (snapped memory size: {_data.Length}) >-------");
            var location = await GetCallingIP();
            var body = new Dictionary<string, string>
            {
                { "message", "hello world" },
                { "location", location }
            };

            return new APIGatewayProxyResponse
            {
                Body = JsonSerializer.Serialize(body),
                StatusCode = 200,
                Headers = new Dictionary<string, string> { { "Content-Type", "application/json" } }
            };
        }
    }
}