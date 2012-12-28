require 'spec_helper'

describe TentD::Model::App do
  let(:app) { Fabricate(:app) }

  describe '#destroy' do
    let!(:app_authorization) { Fabricate(:app_authorization, :app => app) }
    let(:notification_subscription) { Fabricate(:notification_subscription, :app_authorization => app_authorization) }

    it 'should destroy app authorizations' do
      expect(lambda {
        expect(lambda {
          app.destroy
        }).to change(described_class, :count).by(-1)
      }).to change(TentD::Model::AppAuthorization, :count).by(-1)
    end

    it 'should destroy notification subscriptions' do
      notification_subscription # create
      expect(lambda {
        app.destroy
      }).to change(TentD::Model::NotificationSubscription, :count).by(-1)
    end
  end

  describe '#as_json' do
    let(:public_attributes) do
      {
        :id => app.public_id,
        :name => app.name,
        :description => app.description,
        :url => app.url,
        :icon => app.icon,
        :redirect_uris => app.redirect_uris,
        :scopes => app.scopes,
        :authorizations => [],
        :created_at => app.created_at.to_i
      }
    end

    context 'without options' do
      it 'should return public_attributes' do
        expect(app.as_json).to eq(public_attributes)
      end
    end

    with_mac_keys = proc do
      it 'should return mac keys' do
        expect(app.as_json(options)).to eq(public_attributes.merge(
          :mac_key_id => app.mac_key_id,
          :mac_key => app.mac_key,
          :mac_algorithm => app.mac_algorithm
        ))
      end
    end

    context 'with options[:mac]' do
      let(:options) { { :mac => true } }
      context &with_mac_keys
    end

    context 'with options[:exclude]' do
      it 'should excude specified keys' do
        attribtues = public_attributes
        attribtues.delete(:id)
        expect(app.as_json(:exclude => [:id])).to eq(attribtues)
      end
    end

    context 'with options[:app]' do
      let!(:app) { Fabricate(:app) }
      let!(:authorization) { Fabricate(:app_authorization, :app => app) }

      it 'should return authorizations' do
        options = { :app => true }
        expect(app.as_json(options)).to eq(public_attributes.merge(
          :authorizations => [authorization.as_json(options)],
          :created_at => app.created_at.to_i,
          :updated_at => app.updated_at.to_i
        ))
      end
    end
  end
end
