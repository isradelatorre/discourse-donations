# frozen_string_literal: true

class SubscriptionRequiredValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == 'f'
    return false if SiteSetting.enable_sso?
    return false if SiteSetting.enable_google_oauth2_logins?
    return false if SiteSetting.enable_twitter_logins?
    return false if SiteSetting.enable_instagram_logins?
    return false if SiteSetting.enable_facebook_logins?
    return false if SiteSetting.enable_github_logins?
    true
  end

  def error_message
    I18n.t('site_settings.errors.subscription_required_setting_invalid')
  end
end