require 'spec_helper'

describe TentD::Model::App do
  let(:app) { Fabricate(:app) }

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
        :authorizations => []
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
      let(:authorization) { Fabricate(:app_authorization) }
      let(:app) { Fabricate(:app, :authorizations => [authorization]) }

      it 'should return authorizations' do
        options = { :app => true }
        expect(app.as_json(options)).to eq(public_attributes.merge(
          :authorizations => [authorization.as_json(options)],
          :created_at => app.created_at.to_time.to_i,
          :updated_at => app.updated_at.to_time.to_i
        ))
      end
    end
  end
end
