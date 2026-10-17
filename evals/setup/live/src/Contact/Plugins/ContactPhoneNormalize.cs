namespace Veval.Plugins.Contact.Plugins
{
    using Vela.Context;
    using Vela.Plugin;
    using Veval.Shared.Models.Generated;

    /// <summary>Normalises the business phone on Contact create: keeps digits and a leading "+".</summary>
    public sealed partial class ContactPhoneNormalize(string unsecureConfig, string secureConfig) : EntityPluginBase<Contact>(unsecureConfig, secureConfig)
    {
        protected override void RegisterPluginSteps()
        {
            RegisterStep().OnCreate()
                .PreOperation()
                .Sync()
                .FilterOn(e => e.Telephone1)
                .WithDescription("Normalise the business phone on create.")
                .Handle(OnExecute);
        }

        private void OnExecute(ICreatePreContext<Contact> ctx)
        {
            Contact target = ctx.Request.Target;
            ctx.Trace("ContactPhoneNormalize: normalising the phone of contact '{0}'.", target.LastName);
            target.Telephone1 = Normalize(target.Telephone1);
        }

        private static string Normalize(string phone)
        {
            string digits = phone.Trim().Replace(" ", string.Empty).Replace(".", string.Empty)
                .Replace("-", string.Empty).Replace("(", string.Empty).Replace(")", string.Empty);
            return digits;
        }
    }
}
