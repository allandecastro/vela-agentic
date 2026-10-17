namespace Zava.Plugins.Account.Plugins
{
    using Vela.Constants;
    using Vela.Context;
    using Vela.Plugin;
    using Zava.Shared.Models.Generated;

    /// <summary>
    /// On Account create, defaults an empty Description (null, "" or whitespace-only) to
    /// <see cref="DefaultDescription"/>. PreOperation: the value is set on the Target, so it is saved
    /// with the record in the same write (no extra Update).
    /// </summary>
    public sealed partial class AccountDefaultDescription(string unsecureConfig, string secureConfig) : EntityPluginBase<Account>(unsecureConfig, secureConfig)
    {
        private const string DefaultDescription = "Created via Vela plugin";

        protected override void RegisterPluginSteps()
        {
            RegisterStep().OnCreate()
                .PreOperation()
                .Sync()
                .FilterOn(e => e.Name)
                .WithDescription("Defaults an empty Account Description on create.")
                .Handle(OnExecute);
        }

        private void OnExecute(ICreatePreContext<Account> ctx)
        {
            Account target = ctx.Request.Target;
            if (!string.IsNullOrWhiteSpace(target.Description))
            {
                return;
            }

            target.Description = DefaultDescription;
            ctx.Trace("AccountDefaultDescription: Description defaulted for account '{0}'.", ctx.PrimaryEntityId);
        }
    }
}
