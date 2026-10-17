namespace Veval.Plugins.Tests
{
    using System;
    using Microsoft.Xrm.Sdk.Query;
    using Vela.Testing;
    using Veval.Plugins.Account.Plugins;
    using Veval.Plugins.Contact.Plugins;
    using Veval.Shared.Models.Generated;
    using Xunit;

    public class LivePluginsTests
    {
        [Fact]
        public void Phone_is_normalised_on_create()
        {
            var p = PluginPipeline.Empty().Register<ContactPhoneNormalize>();
            var id = p.Service.Create(new Contact { LastName = "Doe", Telephone1 = "+33 (0)1 23.45-67" });
            var row = p.Service.Retrieve(Contact.EntityLogicalNameValue, id, new ColumnSet(true)).ToEntity<Contact>();
            Assert.Equal("+3301234567", row.Telephone1);
        }

        [Fact]
        public void Region_is_stamped_on_create()
        {
            var p = PluginPipeline.Empty().Register<AccountRegionStamp>();
            var id = p.Service.Create(new Account { Name = "Contoso", Address1_Country = "France" });
            var row = p.Service.Retrieve(Account.EntityLogicalNameValue, id, new ColumnSet(true)).ToEntity<Account>();
            Assert.Equal("Region: EMEA", row.Description);
        }

        [Fact]
        public void Region_is_restamped_when_the_country_changes()
        {
            var id = Guid.NewGuid();
            var p = PluginPipeline.Empty().Register<AccountRegionStamp>().Seed(new Account { Id = id, Name = "Contoso" });
            p.Service.Update(new Account { Id = id, Address1_Country = "Canada" });
            var row = p.Service.Retrieve(Account.EntityLogicalNameValue, id, new ColumnSet(true)).ToEntity<Account>();
            Assert.Equal("Region: AMER", row.Description);
        }
    }
}
