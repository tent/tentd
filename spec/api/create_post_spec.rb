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


  context "without authentication" do
    context "when app registration post" do
      let(:post_type) { 'https://tent.io/types/app/v0#' }

      it "creates post" do
        expect {
          client.post.create(data)
        }.to change(TentD::Model::Post, :count).by(1)
        expect(last_response.status).to eql(200)

        response_data = parse_json(last_response.body)
        data.each_pair do |key, val|
          expect(response_data).to have_key(key.to_s)
          expect(encode_json(response_data[key.to_s])).to eql(encode_json(val))
        end
      end
    end
  end
end
