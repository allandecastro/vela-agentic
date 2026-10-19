namespace Zava.Plugins.Tests.Account.Plugins
{
    using System;
    using System.Linq;
    using Microsoft.Xrm.Sdk;
    using Vela.Constants;
    using Vela.Steps;
    using Vela.Testing;
    using Xunit;
    using Zava.Plugins.Account.Plugins;
    using Zava.Shared.Models.Generated;

    /// <summary>
    /// Acceptance cases of docs/features/account-default-description/README.md:
    /// "When an Account is created, if its Description is empty (null, "" or whitespace-only),
    /// set it to 'Created via Vela plugin'."
    /// </summary>
    public sealed class AccountDefaultDescriptionTests
    {
        private const string DefaultDescription = "Created via Vela plugin";

        private static Account RunCreate(Account target, InMemoryOrganizationService crm)
        {
            PluginContext.For<Account>()
                .WithTarget(target)
                .WithOrganizationService(crm)
                .Execute(new AccountDefaultDescription(string.Empty, string.Empty));
            return target;
        }

        // AC1 - Description not sent (null) -> defaulted.
        [Fact]
        public void Null_Description_Is_Defaulted()
        {
            var crm = new InMemoryOrganizationService();
            Account target = RunCreate(new Account { Id = Guid.NewGuid(), Name = "Contoso" }, crm);

            Assert.Equal(DefaultDescription, target.Description);
            Assert.Empty(crm.GetAll(Account.EntityLogicalNameValue));   // PreOperation: no extra write
        }

        // AC2 - empty string -> defaulted.
        [Fact]
        public void Empty_String_Description_Is_Defaulted()
        {
            var crm = new InMemoryOrganizationService();
            Account target = RunCreate(new Account { Id = Guid.NewGuid(), Name = "Contoso", Description = string.Empty }, crm);

            Assert.Equal(DefaultDescription, target.Description);
            Assert.Empty(crm.GetAll(Account.EntityLogicalNameValue));
        }

        // AC3 - whitespace-only (spaces, tab, newline) -> defaulted.
        [Theory]
        [InlineData("   ")]
        [InlineData("\t")]
        [InlineData(" \r\n ")]
        public void Whitespace_Only_Description_Is_Defaulted(string description)
        {
            var crm = new InMemoryOrganizationService();
            Account target = RunCreate(new Account { Id = Guid.NewGuid(), Name = "Contoso", Description = description }, crm);

            Assert.Equal(DefaultDescription, target.Description);
            Assert.Empty(crm.GetAll(Account.EntityLogicalNameValue));
        }

        // AC4 - non-empty Description -> left untouched (not trimmed, not replaced).
        [Theory]
        [InlineData("Key account")]
        [InlineData("  Key account  ")]
        public void Non_Empty_Description_Is_Left_Untouched(string description)
        {
            var crm = new InMemoryOrganizationService();
            Account target = RunCreate(new Account { Id = Guid.NewGuid(), Name = "Contoso", Description = description }, crm);

            Assert.Equal(description, target.Description);
            Assert.Empty(crm.GetAll(Account.EntityLogicalNameValue));
        }

        // AC5 - pipeline: a create with Name fires the step once (Create, PreOperation, Sync) and the saved row carries the default.
        [Fact]
        public void Create_With_Name_Fires_Once_And_Saves_Default()
        {
            PluginPipeline p = PluginPipeline.Empty().Register<AccountDefaultDescription>();

            p.Service.Create(new Account { Id = Guid.NewGuid(), Name = "Contoso" });

            var run = Assert.Single(p.ExecutionLog);
            Assert.True(run.HandlerInvoked);
            Assert.Equal("Create", run.Message);
            Assert.Equal(PluginStages.PreOperation, run.Stage);
            Assert.Equal(ExecutionMode.Synchronous, run.Mode);
            Account saved = Assert.Single(p.GetAll(Account.EntityLogicalNameValue)).ToEntity<Account>();
            Assert.Equal(DefaultDescription, saved.Description);
        }

        // AC5 (negative) - pipeline: the step runs on a create with a Description and the saved value is unchanged.
        [Fact]
        public void Create_With_Description_Runs_And_Keeps_Value()
        {
            PluginPipeline p = PluginPipeline.Empty().Register<AccountDefaultDescription>();

            p.Service.Create(new Account { Id = Guid.NewGuid(), Name = "Contoso", Description = "Key account" });

            var run = Assert.Single(p.ExecutionLog);
            Assert.True(run.HandlerInvoked);
            Account saved = Assert.Single(p.GetAll(Account.EntityLogicalNameValue)).ToEntity<Account>();
            Assert.Equal("Key account", saved.Description);
        }

        // AC6 - pipeline: a create sending no Name does not fire (FilterOn gates Create) - the documented residual risk.
        [Fact]
        public void Create_Without_Name_Does_Not_Fire()
        {
            PluginPipeline p = PluginPipeline.Empty().Register<AccountDefaultDescription>();

            p.Service.Create(new Account { Id = Guid.NewGuid(), AccountNumber = "A-1" });

            Assert.Empty(p.ExecutionLog);
            Account saved = Assert.Single(p.GetAll(Account.EntityLogicalNameValue)).ToEntity<Account>();
            Assert.Null(saved.Description);
        }
    }
}
