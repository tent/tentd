require 'spec_helper'
require 'support/json'
require 'support/post_content_generator'

describe "POST /posts" do
  def app
    TentD::API.new
  end

  let(:data) do
    {
      :type => post_type,
      :content => content_for_post_type(post_type)
    }
  end

  let(:attachments) { [] }
  let(:mentions) { [] }
  let(:create_post_options) { Hash.new }

  before do
    create_post_options[:attachments] = attachments if attachments.any?
    data[:mentions] = mentions if mentions.any?
  end

  shared_examples "a valid create post request" do
    it "creates post" do
      expect {
        expect {
          client.post.create(data, params = {}, create_post_options)
        }.to change(TentD::Model::Post, :count).by(1)
      }.to change(TentD::Model::Mention, :count).by(mentions.size)
      expect(last_response.status).to eql(200)

      response_data = parse_json(last_response.body)
      data.each_pair do |key, val|
        expect(response_data).to have_key(key.to_s)
        expect(encode_json(response_data[key.to_s])).to eql(encode_json(val))
      end

      if attachments.empty?
        expect(data).to_not have_key('attachments')
      end

      if mentions.empty?
        expect(data).to_not have_key('mentions')
      end
    end
  end

  context "without authentication" do
    context "when app registration post" do
      let(:post_type) { 'https://tent.io/types/app/v0#' }

      it_behaves_like "a valid create post request"

      context "with attachment" do
        it_behaves_like "a valid create post request"

        let(:attachments) { [generate_app_icon_attachment] }

        it "creates attachment" do
          expect {
            expect {
              client.post.create(data, params = {}, :attachments => attachments)
            }.to change(TentD::Model::Attachment, :count).by(1)
          }.to change(TentD::Model::PostsAttachment, :count).by(1)
          expect(last_response.status).to eql(200)

          response_data = parse_json(last_response.body)
          expect(response_data['attachments']).to eql(attachments.map { |attachment|
            {
              'name' => attachment[:filename],
              'category' => attachment[:category],
              'content_type' => attachment[:content_type],
              'digest' => TentD::Utils.hex_digest(attachment[:data]),
              'size' => attachment[:data].size,
            }
          })
        end

        context "when identical attachment exists" do
          before do
            attachments.each do |attachment|
              TentD::Model::Attachment.create(
                :digest => TentD::Utils.hex_digest(attachment[:data]),
                :data => attachment[:data],
                :size => attachment[:data].size
              )
            end
          end

          it "uses existing attachment" do
            expect {
              expect {
                client.post.create(data, params = {}, :attachments => attachments)
              }.to_not change(TentD::Model::Attachment, :count)
            }.to change(TentD::Model::PostsAttachment, :count).by(1)
            expect(last_response.status).to eql(200)

            response_data = parse_json(last_response.body)
            expect(response_data['attachments']).to eql(attachments.map { |attachment|
              {
                'name' => attachment[:filename],
                'category' => attachment[:category],
                'content_type' => attachment[:content_type],
                'digest' => TentD::Utils.hex_digest(attachment[:data]),
                'size' => attachment[:data].size,
              }
            })
          end
        end
      end
    end
  end

  context "with authentication" do
    let!(:app_post) do
      TentD::Model::Post.create_from_env(
        TentD::Utils::Hash.stringify_keys(
          :current_user => current_user,
          :data => {
            :type => "https://tent.io/types/app/v0#",
            :content => generate_app_content
          }
        )
      )
    end

    let(:read_post_types) { [] }
    let(:write_post_types) { [] }
    let!(:app_auth_post) do
      TentD::Model::Post.create_from_env(
        TentD::Utils::Hash.stringify_keys(
          :current_user => current_user,
          :data => {
            :type => "https://tent.io/types/app-auth/v0#",
            :content => {
              :post_types => {
                :read => read_post_types,
                :write => write_post_types
              }
            },
            :mentions => [
              { :entity => app_post.entity, :post => app_post.public_id }
            ]
          }
        )
      )
    end

    let!(:credentials_post) { TentD::Model::Credentials.generate(current_user, app_post) }
    let(:client_options) do
      {
        :credentials => TentD::Model::Credentials.slice_credentials(credentials_post)
      }
    end

    context "when status post" do
      let(:post_type) { 'https://tent.io/types/status/v0#' }

      context "when authorized" do
        let(:read_post_types) { %w( https://tent.io/types/status/v0# ) }
        let(:write_post_types) { read_post_types }

        it_behaves_like "a valid create post request"

        context "with mentions" do
          let(:first_mention_entity) { "https://foo.example.com/some-entity" }
          let(:second_mention_entity) { "https://bar.example.com/another-entity" }
          let(:mentions) do
            [
              { :entity => first_mention_entity },
              { :entity => second_mention_entity, :post => "some-random-post" },
            ]
          end

          it_behaves_like "a valid create post request"
        end
      end

      context "when not authorized" do
        it "returns 403"
      end
    end
  end
end
