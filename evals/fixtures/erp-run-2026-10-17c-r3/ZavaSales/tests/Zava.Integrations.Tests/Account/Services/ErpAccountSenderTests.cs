namespace Zava.Integrations.Tests.Account.Services
{
    using System;
    using System.Diagnostics;
    using System.IO;
    using System.Linq;
    using System.Net;
    using System.Net.Http;
    using System.Runtime.Serialization;
    using System.Runtime.Serialization.Json;
    using System.Text;
    using System.Threading;
    using System.Threading.Tasks;
    using Microsoft.Xrm.Sdk;
    using Xunit;
    using Zava.Integrations.Account.Services;

    /// <summary>
    /// Tests for the real <see cref="ErpAccountSender"/> against a fake HttpMessageHandler - no network.
    /// </summary>
    public sealed class ErpAccountSenderTests
    {
        private const string ApiKey = "test-api-key-7f3c";

        // AC3 - POST to the ERP endpoint, JSON body {"id","name"}, X-Api-Key header; any 2xx is success.
        [Theory]
        [InlineData(HttpStatusCode.OK)]
        [InlineData(HttpStatusCode.Created)]
        [InlineData(HttpStatusCode.NoContent)]
        public void Posts_Id_And_Name_As_Json_With_Api_Key(HttpStatusCode status)
        {
            var handler = new RecordingHandler(status);
            var sender = new ErpAccountSender(ApiKey, handler, TimeSpan.FromSeconds(5));
            var id = new Guid("3F2B8C1D-0A4E-4B6F-9C7D-112233445566");

            sender.Send(id, "Contoso");

            Assert.Equal(1, handler.Count);
            Assert.Equal(HttpMethod.Post, handler.Method);
            Assert.Equal(new Uri("https://erp.zava-demo.com/api/accounts"), handler.Uri);
            Assert.Equal("application/json", handler.MediaType);
            Assert.Equal(ApiKey, handler.ApiKey);
            Assert.Equal("{\"id\":\"3f2b8c1d-0a4e-4b6f-9c7d-112233445566\",\"name\":\"Contoso\"}", handler.Body);
        }

        // AC4 - a non-2xx answer fails the job with the status code in the message.
        [Theory]
        [InlineData(HttpStatusCode.InternalServerError, "500")]
        [InlineData(HttpStatusCode.Unauthorized, "401")]
        [InlineData(HttpStatusCode.ServiceUnavailable, "503")]
        public void Non_Success_Status_Throws_InvalidPluginExecutionException(HttpStatusCode status, string code)
        {
            var sender = new ErpAccountSender(ApiKey, new RecordingHandler(status), TimeSpan.FromSeconds(5));

            var ex = Assert.Throws<InvalidPluginExecutionException>(() => sender.Send(Guid.NewGuid(), "Contoso"));

            Assert.Contains(code, ex.Message);
            Assert.DoesNotContain(ApiKey, ex.Message);
        }

        // AC5 - ERP unreachable (transport error) fails the job with InvalidPluginExecutionException.
        [Fact]
        public void Unreachable_Erp_Throws_InvalidPluginExecutionException()
        {
            var sender = new ErpAccountSender(ApiKey, new FailingHandler(), TimeSpan.FromSeconds(5));

            Assert.Throws<InvalidPluginExecutionException>(() => sender.Send(Guid.NewGuid(), "Contoso"));
        }

        // AC6 - the ERP never answers: the call fails within the explicit timeout, not the 100 s default.
        [Fact]
        public void Never_Answering_Erp_Times_Out()
        {
            var sender = new ErpAccountSender(ApiKey, new NeverAnsweringHandler(), TimeSpan.FromMilliseconds(300));
            var watch = Stopwatch.StartNew();

            var ex = Assert.Throws<InvalidPluginExecutionException>(() => sender.Send(Guid.NewGuid(), "Contoso"));

            watch.Stop();
            Assert.True(watch.Elapsed < TimeSpan.FromSeconds(10), "took " + watch.Elapsed);
            Assert.Contains("timed out", ex.Message);
        }

        // AC6 - the production timeout is explicit and well under the 2-minute sandbox limit.
        [Fact]
        public void Production_Timeout_Is_Explicit()
        {
            Assert.Equal(TimeSpan.FromSeconds(30), ErpAccountSender.DefaultTimeout);
        }

        // AC7 - quotes, backslash, slash and non-ASCII in the name still produce valid JSON with the same name.
        [Fact]
        public void Special_Characters_In_Name_Produce_Valid_Json()
        {
            const string name = "He said \"hi\" \\ A/B Zoë 東京\t";
            var handler = new RecordingHandler(HttpStatusCode.OK);
            var sender = new ErpAccountSender(ApiKey, handler, TimeSpan.FromSeconds(5));
            var id = Guid.NewGuid();

            sender.Send(id, name);

            var parsed = Parse(handler.Body);
            Assert.Equal(id.ToString("D"), parsed.Id);
            Assert.Equal(name, parsed.Name);
        }

        private static ParsedBody Parse(string json)
        {
            var serializer = new DataContractJsonSerializer(typeof(ParsedBody));
            using (var stream = new MemoryStream(Encoding.UTF8.GetBytes(json)))
            {
                return (ParsedBody)serializer.ReadObject(stream);
            }
        }

        [DataContract]
        public sealed class ParsedBody
        {
            [DataMember(Name = "id")]
            public string Id { get; set; }

            [DataMember(Name = "name")]
            public string Name { get; set; }
        }

        private sealed class RecordingHandler(HttpStatusCode status) : HttpMessageHandler
        {
            public int Count { get; private set; }
            public HttpMethod Method { get; private set; }
            public Uri Uri { get; private set; }
            public string MediaType { get; private set; }
            public string ApiKey { get; private set; }
            public string Body { get; private set; }

            protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            {
                Count++;
                Method = request.Method;
                Uri = request.RequestUri;
                MediaType = request.Content?.Headers.ContentType?.MediaType;
                ApiKey = request.Headers.TryGetValues("X-Api-Key", out var values) ? values.Single() : null;
                Body = request.Content == null ? null : await request.Content.ReadAsStringAsync().ConfigureAwait(false);
                return new HttpResponseMessage(status);
            }
        }

        private sealed class FailingHandler : HttpMessageHandler
        {
            protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
                => throw new HttpRequestException("No such host is known.");
        }

        private sealed class NeverAnsweringHandler : HttpMessageHandler
        {
            protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
            {
                await Task.Delay(Timeout.Infinite, cancellationToken).ConfigureAwait(false);
                return new HttpResponseMessage(HttpStatusCode.OK);
            }
        }
    }
}
