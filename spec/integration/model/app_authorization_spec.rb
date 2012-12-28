require 'spec_helper'

describe TentD::Model::AppAuthorization do
  let(:app_authorization) { Fabricate(:app_authorization, :app => Fabricate(:app)) }
  let(:current_user) { TentD::Model::User.current }
  let(:other_user) { TentD::Model::User.create }

  describe '.follow_url' do
    let(:entity) { 'https://johndoe.example.org' }

    it 'should find app authorization with follow_ui scope and follow_url' do
      Fabricate(:app_authorization, :app => Fabricate(:app), :scopes => %w{ follow_ui }, :follow_url => 'https://follow.example.org/awesome-ui')
      app_auth = Fabricate(:app_authorization, :app => Fabricate(:app), :scopes => %w{ read_posts follow_ui write_posts }, :follow_url => 'https://follow.example.com')

      follow_url = described_class.follow_url(entity)
      expect(follow_url).to eql("#{app_auth.follow_url}?entity=#{URI.encode_www_form_component(entity)}")
    end

    it 'should not find app authorization with follow_ui scope for another user' do
      app_auth = Fabricate(:app_authorization, :app => Fabricate(:app, :user_id => other_user.id), :scopes => %w{ read_posts follow_ui write_posts }, :follow_url => 'https://follow.example.com')

      follow_url = described_class.follow_url(entity)
      expect(follow_url).to be_nil
    end
  end

  it 'should only allow a single app authorization to have a follow_url' do
    app = Fabricate(:app)

    auth = Fabricate(:app_authorization,
      :app => app,
      :follow_url => 'https://example.com/ui',
      :scopes => %w( follow_ui )
    )

    auth2 = Fabricate(:app_authorization,
      :app => app,
      :follow_url => 'https://example.com/ui2',
      :scopes => %w( follow_ui )
    )

    expect(auth.reload.scopes).to be_empty
    expect(auth2.reload.scopes).to eql(['follow_ui'])
  end

  describe '#destroy' do
    let(:notification_subscription) { Fabricate(:notification_subscription, :app_authorization => app_authorization) }

    it 'should delete app authorization' do
      app_authorization # create
      expect(lambda {
        app_authorization.destroy
      }).to change(TentD::Model::AppAuthorization, :count).by(-1)
    end

    it 'should delete notification subscription' do
      notification_subscription # create
      expect(lambda {
        app_authorization.destroy
      }).to change(TentD::Model::NotificationSubscription, :count).by(-1)
    end
  end

  describe '#as_json' do
    let(:app_attributes) do
      {
        :id => app_authorization.public_id,
        :post_types => app_authorization.post_types,
        :profile_info_types => app_authorization.profile_info_types,
        :scopes => app_authorization.scopes,
        :notification_url => app_authorization.notification_url,
        :created_at => app_authorization.created_at.to_time.to_i,
        :updated_at => app_authorization.updated_at.to_time.to_i
      }
    end

    context 'with options[:app]' do
      let(:options) { { :app => true } }

      it 'should return everything except mac stuff' do
        expect(app_authorization.as_json(options)).to eql(app_attributes)
      end

      context 'and options[:authorization_token]' do
        before { options[:authorization_token] = true }
        it 'should return token code' do
          expect(app_authorization.as_json(options)).to eql(app_attributes.merge(
            :token_code => app_authorization.token_code
          ))
        end
      end

      context 'and options[:mac]' do
        before { options[:mac] = true }

        it 'should return mac stuff' do
          expect(app_authorization.as_json(options)).to eql(app_attributes.merge(
            :mac_key_id => app_authorization.mac_key_id,
            :mac_key => app_authorization.mac_key,
            :mac_algorithm => app_authorization.mac_algorithm
          ))
        end
      end
    end
  end
end
