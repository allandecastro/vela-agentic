namespace Zava.Integrations.Tests.Account.Plugins
{
    using System;
    using System.Collections.Generic;
    using System.Linq;
    using Microsoft.Xrm.Sdk;
    using Vela.Constants;
    using Vela.Steps;
    using Vela.Testing;
    using Xunit;
    using Zava.Integrations.Account.Plugins;
    using Zava.Integrations.Account.Services;
    using Zava.Shared.Models.Generated;

    /// <summary>
    /// Pipeline tests for <see cref="AccountErpNotify"/>: the step's registration (Create, PostOperation, Async,
    /// FilterOn Name, secure config ErpApiKey) and what it hands the ERP sender. The sender is replaced with a fake
    /// through WithService - no test reaches the network.
    /// </summary>
    public sealed class AccountErpNotifyTests
    {
        private const string ApiKey = "test-api-key-7f3c";

        private static PluginPipeline Pipeline(FakeErpSender fake, string apiKey = ApiKey)
        {
            PluginPipeline pipeline = PluginPipeline.Empty().WithService<IErpAccountSender>(fake);
            if (apiKey != null)
            {
                pipeline = pipeline.WithSecureConfig("ErpApiKey", apiKey);
            }

            return pipeline.Register<AccountErpNotify>();
        }

        // AC1 - the step fires once on Create (PostOperation, Async) and sends the new id and name.
        [Fact]
        public void Fires_On_Create_PostOperation()
        {
            var fake = new FakeErpSender();
            PluginPipeline pipeline = Pipeline(fake);

            Guid id = pipeline.Service.Create(new Account { Name = "Contoso" });

            var run = Assert.Single(pipeline.ExecutionLog);
            Assert.Equal(typeof(AccountErpNotify).FullName, run.PluginTypeName);
            Assert.Equal("Create", run.Message);
            Assert.Equal(PluginStages.PostOperation, run.Stage);
            Assert.Equal(ExecutionMode.Asynchronous, run.Mode);
            Assert.True(run.HandlerInvoked);
            Assert.Empty(pipeline.AsyncStepFailures);

            var call = Assert.Single(fake.Calls);
            Assert.Equal(id, call.Key);
            Assert.Equal("Contoso", call.Value);
        }

        // AC2 - the ERP call fails: the account is still saved, the failure is a failed async job (not thrown).
        [Fact]
        public void Erp_Failure_Does_Not_Block_The_Save()
        {
            var fake = new FakeErpSender { Failure = new InvalidPluginExecutionException("ERP returned 503 (Service Unavailable).") };
            PluginPipeline pipeline = Pipeline(fake);

            Guid id = pipeline.Service.Create(new Account { Name = "Contoso" });   // does not throw

            Assert.Single(pipeline.AsyncStepFailures);
            Assert.Single(fake.Calls);
            var row = Assert.Single(pipeline.GetAll("account"));
            Assert.Equal(id, row.Id);
            Assert.Equal("Contoso", row.GetAttributeValue<string>("name"));
        }

        // AC8 - no secure config: failed async job, no ERP call, account saved.
        [Theory]
        [InlineData(null)]
        [InlineData("")]
        [InlineData("   ")]
        public void Missing_Api_Key_Fails_The_Job_Without_Calling_The_Erp(string apiKey)
        {
            var fake = new FakeErpSender();
            PluginPipeline pipeline = Pipeline(fake, apiKey);

            pipeline.Service.Create(new Account { Name = "Contoso" });

            var run = Assert.Single(pipeline.ExecutionLog);
            Assert.True(run.HandlerInvoked);
            Assert.Single(pipeline.AsyncStepFailures);
            Assert.Empty(fake.Calls);
            Assert.Single(pipeline.GetAll("account"));
        }

        // AC9 - a Create that does not send name does not fire the step (Create filter gate).
        [Fact]
        public void Create_Without_Name_Does_Not_Fire()
        {
            var fake = new FakeErpSender();
            PluginPipeline pipeline = Pipeline(fake);

            pipeline.Service.Create(new Account { AccountNumber = "A-1" });

            Assert.Empty(pipeline.ExecutionLog);
            Assert.Empty(fake.Calls);
            Assert.Single(pipeline.GetAll("account"));
        }

        // AC10 - an Update (even of name) does not fire the step: Create only.
        [Fact]
        public void Update_Does_Not_Fire()
        {
            var fake = new FakeErpSender();
            PluginPipeline pipeline = Pipeline(fake);
            Guid id = Guid.NewGuid();
            pipeline.Seed(new Account { Id = id, Name = "Old" });

            pipeline.Service.Update(new Account { Id = id, Name = "New" });

            Assert.Empty(pipeline.ExecutionLog);
            Assert.Empty(fake.Calls);
        }

        // AC11 - the API key never lands in the trace (Plugin Trace Log).
        [Fact]
        public void Api_Key_Is_Not_Traced()
        {
            var fake = new FakeErpSender();
            PluginPipeline pipeline = Pipeline(fake);

            Guid id = pipeline.Service.Create(new Account { Name = "Contoso" });

            string trace = string.Join("\n", pipeline.Trace.Traces);
            Assert.Contains(id.ToString(), trace);
            Assert.DoesNotContain(ApiKey, trace);
        }

        private sealed class FakeErpSender : IErpAccountSender
        {
            public List<KeyValuePair<Guid, string>> Calls { get; } = new List<KeyValuePair<Guid, string>>();

            public Exception Failure { get; set; }

            public void Send(Guid accountId, string name)
            {
                Calls.Add(new KeyValuePair<Guid, string>(accountId, name));
                if (Failure != null)
                {
                    throw Failure;
                }
            }
        }
    }
}
