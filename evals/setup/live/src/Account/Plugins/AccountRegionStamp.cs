namespace Veval.Plugins.Account.Plugins
{
    using System;
    using Vela.Context;
    using Vela.Plugin;
    using Veval.Shared.Models.Generated;

    /// <summary>Stamps the sales region into the account description from the address country.</summary>
    public sealed partial class AccountRegionStamp(string unsecureConfig, string secureConfig) : EntityPluginBase<Account>(unsecureConfig, secureConfig)
    {
        protected override void RegisterPluginSteps()
        {
            RegisterStep().OnCreate()
                .PreOperation()
                .Sync()
                .FilterOn(e => e.Address1_Country)
                .WithDescription("Stamp the sales region on create.")
                .WithExecutionOrder(10)
                .Handle(OnExecute);

            RegisterStep().OnUpdate()
                .PreOperation()
                .Sync()
                .FilterOn(e => e.Address1_Country)
                .WithDescription("Stamp the sales region when the country changes.")
                .WithExecutionOrder(10)
                .Handle(HandleUpdate);
        }

        private void HandleUpdate(IUpdatePreContext<Account> ctx) => Stamp(ctx.Request.Target);

        private void OnExecute(ICreatePreContext<Account> ctx) => Stamp(ctx.Request.Target);

        private static void Stamp(Account target) => target.Description = "Region: " + RegionOf(target.Address1_Country);

        private static string RegionOf(string country)
        {
            switch ((country ?? string.Empty).Trim().ToUpperInvariant())
            {
                case "FRANCE": case "GERMANY": case "SPAIN": case "UNITED KINGDOM": return "EMEA";
                case "UNITED STATES": case "CANADA": case "MEXICO": return "AMER";
                case "JAPAN": case "AUSTRALIA": case "SINGAPORE": return "APAC";
                default: return "Other";
            }
        }
    }
}
