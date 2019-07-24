require 'rails_helper'
require_relative '../../support/dd_helper'

shared_examples 'failure response' do |message_key|
  let(:body) { JSON.parse(response.body) }

  it 'has status 200' do expect(response).to have_http_status(200) end
  it 'has an error message' do expect(body['messages']).to include(I18n.t(message_key)) end
  it 'is not successful' do expect(body['success']).to eq false end
  it 'does not create a payment' do DiscourseDonations::Stripe.expects(:new).never end
  it 'does not create rewards' do DiscourseDonations::Rewards.expects(:new).never end
  it 'does not queue up any jobs' do ::Jobs.expects(:enqueue).never end
end

module DiscourseDonations
  RSpec.describe ChargesController, type: :controller do
    routes { DiscourseDonations::Engine.routes }
    let(:body) { JSON.parse(response.body) }

    before do
      SiteSetting.stubs(:disable_discourse_narrative_bot_welcome_post).returns(true)
      SiteSetting.stubs(:discourse_donations_secret_key).returns('secret-key-yo')
      SiteSetting.stubs(:discourse_donations_description).returns('charity begins at discourse plugin')
      SiteSetting.stubs(:discourse_donations_currency).returns('AUD')
    end

    # Workaround for rails-5 issue. See https://github.com/thoughtbot/shoulda-matchers/issues/1018#issuecomment-315876453
    let(:allowed_params) { {email: 'email@example.com', password: 'secret', username: 'mr-pink', name: 'kirsten', amount: 100, stripeToken: 'rrurrrurrrrr'} }

    it 'whitelists the params' do
      should permit(:name, :username, :email, :password).
          for(:create, params: { params: allowed_params })
    end

    it 'responds ok for anonymous users' do
      post :create, params: { email: 'foobar@example.com' }
      expect(body['messages'][0]).to end_with(I18n.t('donations.payment.success'))
      expect(response).to have_http_status(200)
    end

    describe 'rewards' do
      let(:body) { JSON.parse(response.body) }
      let(:stripe) { ::Stripe::Charge }

      shared_examples 'no rewards' do
        it 'has no rewards' do
          post :create, params: params
          expect(body['rewards']).to be_empty
        end
      end

      describe 'logged in user' do
        before do
          log_in :coding_horror
        end

        include_examples 'no rewards' do
          let(:params) { {} }

          before do
            stripe.stubs(:create).returns({ 'paid' => true })
            SiteSetting.stubs(:discourse_donations_reward_group_name).returns(nil)
            SiteSetting.stubs(:discourse_donations_reward_badge_name).returns(nil)
          end
        end

        describe 'rewards' do
          let(:group_name) { 'Zasch' }
          let(:badge_name) { 'Beanie' }
          let!(:grp) { Fabricate(:group, name: group_name) }
          let!(:badge) { Fabricate(:badge, name: badge_name) }

          before do
            SiteSetting.stubs(:discourse_donations_reward_group_name).returns(group_name)
            SiteSetting.stubs(:discourse_donations_reward_badge_name).returns(badge_name)
            stripe.stubs(:create).returns({ 'paid' => true })
          end

          it 'awards a group' do
            post :create
            expect(body['rewards']).to include({'type' => 'group', 'name' => group_name})
          end

          it 'awards a badge' do
            post :create
            expect(body['rewards']).to include({'type' => 'badge', 'name' => badge_name})
          end
        end
      end
    end
  end
end
