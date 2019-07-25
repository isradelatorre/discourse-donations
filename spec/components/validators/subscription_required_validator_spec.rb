# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SubscriptionRequiredValidator do
  subject { described_class.new }

  describe '#valid_value?' do
    describe 'when enable_sso is set' do
      before do
        SiteSetting.sso_url = 'https://example.com/sso'
        SiteSetting.enable_sso = true
      end

      describe 'when value is false' do
        it 'should be valid' do
          expect(subject.valid_value?('f')).to eq(true)
        end
      end


      describe 'when value is true' do
        it 'should not be valid' do
          expect(subject.valid_value?('t')).to eq(false)

          expect(subject.error_message).to eq(I18n.t(
            'site_settings.errors.subscription_required_setting_invalid'
          ))
        end
      end
    end

    describe 'when enable_google_oauth2_logins is set' do
      before do
        SiteSetting.enable_google_oauth2_logins = true
      end

      describe 'when value is false' do
        it 'should be valid' do
          expect(subject.valid_value?('f')).to eq(true)
        end
      end


      describe 'when value is true' do
        it 'should not be valid' do
          expect(subject.valid_value?('t')).to eq(false)

          expect(subject.error_message).to eq(I18n.t(
            'site_settings.errors.subscription_required_setting_invalid'
          ))
        end
      end
    end

    describe 'when enable_twitter_logins is set' do
      before do
        SiteSetting.enable_twitter_logins = true
      end

      describe 'when value is false' do
        it 'should be valid' do
          expect(subject.valid_value?('f')).to eq(true)
        end
      end


      describe 'when value is true' do
        it 'should not be valid' do
          expect(subject.valid_value?('t')).to eq(false)

          expect(subject.error_message).to eq(I18n.t(
            'site_settings.errors.subscription_required_setting_invalid'
          ))
        end
      end
    end

    describe 'when enable_instagram_logins is set' do
      before do
        SiteSetting.enable_instagram_logins = true
      end

      describe 'when value is false' do
        it 'should be valid' do
          expect(subject.valid_value?('f')).to eq(true)
        end
      end


      describe 'when value is true' do
        it 'should not be valid' do
          expect(subject.valid_value?('t')).to eq(false)

          expect(subject.error_message).to eq(I18n.t(
            'site_settings.errors.subscription_required_setting_invalid'
          ))
        end
      end
    end

    describe 'when enable_facebook_logins is set' do
      before do
        SiteSetting.enable_facebook_logins = true
      end

      describe 'when value is false' do
        it 'should be valid' do
          expect(subject.valid_value?('f')).to eq(true)
        end
      end


      describe 'when value is true' do
        it 'should not be valid' do
          expect(subject.valid_value?('t')).to eq(false)

          expect(subject.error_message).to eq(I18n.t(
            'site_settings.errors.subscription_required_setting_invalid'
          ))
        end
      end
    end

    describe 'when enable_github_logins is set' do
      before do
        SiteSetting.enable_github_logins = true
      end

      describe 'when value is false' do
        it 'should be valid' do
          expect(subject.valid_value?('f')).to eq(true)
        end
      end


      describe 'when value is true' do
        it 'should not be valid' do
          expect(subject.valid_value?('t')).to eq(false)

          expect(subject.error_message).to eq(I18n.t(
            'site_settings.errors.subscription_required_setting_invalid'
          ))
        end
      end
    end
  end
end