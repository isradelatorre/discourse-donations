# name: discourse-donations
# about: Integrates Stripe into Discourse to allow forum visitors to make donations
# version: 1.11.1
# url: https://github.com/chrisbeach/discourse-donations
# authors: Rimian Perkins, Chris Beach, Angus McLeod

gem 'net-http-persistent', '3.0.1', {require: false}
gem 'stripe', '4.21.3'

register_asset "stylesheets/common/discourse-donations.scss"
register_asset "stylesheets/mobile/discourse-donations.scss"

enabled_site_setting :discourse_donations_enabled

register_html_builder('server:before-head-close') do
  "<script src='https://js.stripe.com/v3/'></script>"
end

extend_content_security_policy(
  script_src: ['https://js.stripe.com/v3/']
)

module SessionControllerPrepend
 
  def create
    if SiteSetting.discourse_donations_subscription_required?
      params.require(:login)
      login = params[:login].strip
      login = login[1..-1] if login[0] == "@"
      if user = User.find_by_username_or_email(login)
        # If they need an active subscription
        if login_has_no_active_subscription_for?(user)
          cookies[:email] = { value: user.email, expires: 1.day.from_now }
          no_active_subscription
        else
          super
        end
      else
        super
      end
    else
      super
    end
  end

  def email_login
    if SiteSetting.discourse_donations_subscription_required?
      token = params[:token]
      # Only check if it is confirmable so as not to 'expire' the token
      if user = EmailToken.confirmable(token).user
        # If they need an active subscription
        if login_has_no_active_subscription_for?(user)
          # Confirm the token if login is not allowed per email login pattern
          EmailToken.confirm(token)
          cookies[:email] = { value: user.email, expires: 1.day.from_now }
          no_active_subscription
        else
          super
        end
      else
        super
      end
    else
      super
    end
  end

  private

  def login_has_no_active_subscription_for?(user)
    SiteSetting.discourse_donations_subscription_required? && !user.subscription_active? && !user.admin? && !user.staff?
  end

  def no_active_subscription
    render json: {
      error: I18n.t("discourse_donations.login.has_no_active_subscription"),
      reason: 'no_active_subscription',
      redirect_to: '/donate'
    }
  end
end

module UsersControllerPrepend

  def logon_after_password_reset
    if SiteSetting.discourse_donations_subscription_required?
      if !@user.subscription_active? && !@user.admin? && !@user.staff?
        @success = I18n.t("discourse_donations.login.has_no_active_subscription")
      else
        super
      end
    else
      super
    end
  end

end

module InvitesControllerPrepend

  def perform_accept_invitation
    if SiteSetting.discourse_donations_subscription_required?
      params.require(:id)
      params.permit(:username, :name, :password, user_custom_fields: {})
      invite = Invite.find_by(invite_key: params[:id])

      if invite.present?
        begin
          user = invite.redeem(username: params[:username], name: params[:name], password: params[:password], user_custom_fields: params[:user_custom_fields], ip_address: request.remote_ip)
          if user.present? && (user.subscription_active? || user.admin? || user.staff?)
            super
          else
            if user.present?
              post_process_invite(user)
            end
            response = { success: true }
            if user.present? && user.active?
              response[:redirect_to] = '/donate'
              response[:message] = I18n.t("discourse_donations.login.has_no_active_subscription")
            else
              response[:message] = I18n.t('invite.confirm_email')
            end

            render json: response
          end

        rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
          render json: {
            success: false,
            errors: e.record&.errors&.to_hash || {},
            message: I18n.t('invite.error_message')
          }
        end
      else
        super
      end
    else
      super
    end
  end

end

load File.expand_path('../lib/validators/subscription_required_validator.rb', __FILE__)

after_initialize do
  load File.expand_path('../lib/discourse_donations/engine.rb', __FILE__)
  load File.expand_path('../config/routes.rb', __FILE__)
  load File.expand_path('../app/controllers/controllers.rb', __FILE__)
  load File.expand_path('../app/jobs/jobs.rb', __FILE__)
  load File.expand_path('../app/services/services.rb', __FILE__)

  Discourse::Application.routes.append do
    mount ::DiscourseDonations::Engine, at: 'donate'
  end
  

  ::SessionController.class_eval do
    prepend SessionControllerPrepend
  end

  ::UsersController.class_eval do
    prepend UsersControllerPrepend
  end

  ::InvitesController.class_eval do
    prepend InvitesControllerPrepend
  end

  class ::User
    def stripe_customer_id
      if custom_fields['stripe_customer_id']
        custom_fields['stripe_customer_id'].to_s
      else
        nil
      end
    end
    def subscription_active?
      stripe = DiscourseDonations::Stripe.new(SiteSetting.discourse_donations_secret_key, {})
      customer = stripe.customer(self, {})
      if customer&.subscriptions&.any? { |s| s.status == "active" }
        true
      else
        false
      end
    end
  end

  Category.register_custom_field_type('donations_show_amounts', :boolean)

  class ::Category
    def donations_cause
      SiteSetting.discourse_donations_causes_categories.split('|').include? self.id.to_s
    end

    def donations_total
      if custom_fields['donations_total']
        custom_fields['donations_total']
      else
        0
      end
    end

    def donations_show_amounts
      if custom_fields['donations_show_amounts'] != nil
        custom_fields['donations_show_amounts']
      else
        false
      end
    end

    def donations_month
      if custom_fields['donations_month']
        custom_fields['donations_month']
      else
        0
      end
    end

    def donations_backers
      if custom_fields['donations_backers']
        [*custom_fields['donations_backers']].map do |user_id|
          User.find_by(id: user_id.to_i)
        end
      else
        []
      end
    end

    def donations_maintainers
      if custom_fields['donations_maintainers']
        custom_fields['donations_maintainers'].split(',').map do |username|
          User.find_by(username: username)
        end
      else
        []
      end
    end

    def donations_maintainers_label
      if custom_fields['donations_maintainers_label']
        custom_fields['donations_maintainers_label']
      else
        nil
      end
    end

    def donations_github
      if custom_fields['donations_github']
        custom_fields['donations_github']
      else
        nil
      end
    end

    def donations_meta
      if custom_fields['donations_meta']
        custom_fields['donations_meta']
      else
        nil
      end
    end

    def donations_release_latest
      if custom_fields['donations_release_latest']
        custom_fields['donations_release_latest']
      else
        nil
      end
    end

    def donations_release_oldest
      if custom_fields['donations_release_oldest']
        custom_fields['donations_release_oldest']
      else
        nil
      end
    end
  end

  [
    'donations_cause',
    'donations_total',
    'donations_month',
    'donations_backers',
    'donations_show_amounts',
    'donations_maintainers',
    'donations_maintainers_label',
    'donations_github',
    'donations_meta',
    'donations_release_latest',
    'donations_release_oldest'
  ].each do |key|
    Site.preloaded_category_custom_fields << key if Site.respond_to? :preloaded_category_custom_fields
  end


  add_to_serializer(:basic_category, :donations_cause) { object.donations_cause }
  add_to_serializer(:basic_category, :donations_total) { object.donations_total }
  add_to_serializer(:basic_category, :include_donations_total?) { object.donations_show_amounts }
  add_to_serializer(:basic_category, :donations_month) { object.donations_month }
  add_to_serializer(:basic_category, :include_donations_month?) { object.donations_show_amounts && SiteSetting.discourse_donations_cause_month }
  add_to_serializer(:basic_category, :donations_backers) {
    ActiveModel::ArraySerializer.new(object.donations_backers, each_serializer: BasicUserSerializer).as_json
  }
  add_to_serializer(:basic_category, :donations_maintainers) {
    ActiveModel::ArraySerializer.new(object.donations_maintainers, each_serializer: BasicUserSerializer).as_json
  }
  add_to_serializer(:basic_category, :donations_maintainers_label) { object.donations_maintainers_label }
  add_to_serializer(:basic_category, :include_donations_maintainers_label?) { object.donations_maintainers_label.present? }
  add_to_serializer(:basic_category, :donations_github) { object.donations_github }
  add_to_serializer(:basic_category, :donations_meta) { object.donations_meta }
  add_to_serializer(:basic_category, :donations_release_latest) { object.donations_release_latest }
  add_to_serializer(:basic_category, :donations_release_oldest) { object.donations_release_oldest }

  DiscourseEvent.trigger(:donations_ready)
end
