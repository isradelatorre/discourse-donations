import { default as computed } from "ember-addons/ember-computed-decorators";
export default Ember.Component.extend({
  bannerDismissed: false,

  @computed("bannerDismissed")
  showSubscriptionRequiredBanner(bannerDismissed) { 
    return (
      Discourse.SiteSettings.discourse_donations_subscription_required &&
      !bannerDismissed
    )
  },
  actions: {
    dismiss() {
      this.set("bannerDismissed", true);
    }
  }
});
