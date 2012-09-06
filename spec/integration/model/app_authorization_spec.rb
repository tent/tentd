require 'spec_helper'

describe TentD::Model::AppAuthorization do
  let(:app_authorization) { Fabricate(:app_authorization, :app => Fabricate(:app)) }

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
        expect(app_authorization.as_json(options)).to eq(app_attributes)
      end

      context 'and options[:authorization_token]' do
        before { options[:authorization_token] = true }
        it 'should return token code' do
          expect(app_authorization.as_json(options)).to eq(app_attributes.merge(
            :token_code => app_authorization.token_code
          ))
        end
      end

      context 'and options[:mac]' do
        before { options[:mac] = true }

        it 'should return mac stuff' do
          expect(app_authorization.as_json(options)).to eq(app_attributes.merge(
            :mac_key_id => app_authorization.mac_key_id,
            :mac_key => app_authorization.mac_key,
            :mac_algorithm => app_authorization.mac_algorithm
          ))
        end
      end
    end
  end
end
