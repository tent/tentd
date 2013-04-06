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
  let(:create_post_options) { Hash.new }

  shared_examples "a valid create post request" do
    it "creates post" do
      expect {
        client.post.create(data, params = {}, create_post_options)
      }.to change(TentD::Model::Post, :count).by(1)
      expect(last_response.status).to eql(200)

      response_data = parse_json(last_response.body)
      data.each_pair do |key, val|
        expect(response_data).to have_key(key.to_s)
        expect(encode_json(response_data[key.to_s])).to eql(encode_json(val))
      end

      if attachments.empty?
        expect(data).to_not have_key('attachments')
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

        before do
          create_post_options[:attachments] = attachments
        end

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
end
