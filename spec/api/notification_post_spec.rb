require 'spec_helper'
require 'support/json'

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

  let(:content_type_header) {}
  let(:link_header) {}
  let(:faraday_request_block) do
    proc do |request|
      request.headers['Content-Type'] = content_type_header if content_type_header
      request.headers['Link'] = link_header if link_header
    end
  end

  let(:remote_entity_url) { %(https://tent.example.com/foo) }
  let(:remote_meta_post_url) { "#{remote_entity_url}/posts/#{URI.encode_www_form_component(remote_entity_url)}/meta-post" }
  let(:remote_meta_post) do
    {
      "entity" => remote_entity_url,
      "previous_entities" => [],
      "content" => {
        "servers" => [
          {
            "version" => "0.3",
            "urls" => {
              "oauth_auth" => "#{remote_entity_url}/oauth/authorize",
              "oauth_token" => "#{remote_entity_url}/oauth/token",
              "posts_feed" => "#{remote_entity_url}/posts",
              "new_post" => "#{remote_entity_url}/posts",
              "post" => "#{remote_entity_url}/posts/{entity}/{post}",
              "post_attachment" => "#{remote_entity_url}/posts/{entity}/{post}/attachments/{name}?version={version}",
              "batch" => "#{remote_entity_url}/batch",
              "server_info" => "#{remote_entity_url}/server"
            },
            "preference" => 0
          }
        ]
      }
    }
  end

  let(:http_stubs) { [] }

  def expect_http_stubs_called
    http_stubs.each { |stub| expect(stub).to have_been_requested }
  end

  context "without authentication" do
    context "when notification post" do
      let(:content_type_header) { (TentD::API::POST_CONTENT_TYPE % post_type) + %(; rel="https://tent.io/rels/notification") }

      context "when relationship#initial" do
        let(:post_type) { "https://tent.io/types/relationship/v0#initial" }

        let(:data) do
          {
            :id => TentD::Utils.random_id,
            :type => post_type,
            :entity => remote_entity_url,
            :published_at => TentD::Utils.timestamp,
            :mentions => [
              {
                :entity => server_entity
              }
            ]
          }
        end

        context "with linked credentials post" do
          let(:credentials_post_id) { TentD::Utils.random_id }
          let(:credentials_post) do
            {
              :id => credentials_post_id,
              :type => "https://tent.io/types/credentials/v0#",
              :entity => remote_entity_url,
              :published_at => TentD::Utils.timestamp,
              :content => {
                :mac_key => TentD::Utils.mac_key,
                :mac_algorithm => TentD::Utils.mac_algorithm
              },
              :mentions => [
                {
                  :entity => remote_entity_url,
                  :post => data[:id]
                }
              ]
            }
          end
          let(:credentials_post_url) { "#{remote_entity_url}/posts/#{URI.encode_www_form_component(remote_entity_url)}/#{credentials_post_id}" }
          let(:link_header) { %(<#{credentials_post_url}>; rel="https://tent.io/rels/credentials") }

          context "when initiating server is discoverable" do
            before do
              ##
              # Stub discovery
              http_stubs << stub_request(:head, remote_entity_url).to_return(
                :headers => {
                  'Link' => %(<#{remote_meta_post_url}>; rel="https://tent.io/rels/meta-post")
                },
              )
              http_stubs << stub_request(:get, remote_meta_post_url).to_return(
                :headers => {
                  'Content-Type' => TentD::API::POST_CONTENT_TYPE % "https://tent.io/types/meta/v0#",
                },
                :body => encode_json(remote_meta_post)
              )
            end

            context "when credentials post fetchable" do
              before do
                http_stubs << stub_request(:get, credentials_post_url).to_return(
                  :headers => {
                    'Content-Type' => TentD::API::POST_CONTENT_TYPE % "https://tent.io/types/credentials/v0#",
                  },
                  :body => encode_json(credentials_post)
                )
              end

              it "imports post" do
                expect {
                  client.post.create(data, &faraday_request_block)
                  expect_http_stubs_called
                  expect(last_response.status).to eql(204), begin
                    if last_response.status == 400
                      parse_json(last_response.body)['error']
                    else
                      "Expected response status of 204, got #{last_response.status}"
                    end
                  end
                }.to change(TentD::Model::Post, :count)
              end
            end

            context "when credentials post can not be fetched" do
              before do
                http_stubs << stub_request(:get, credentials_post_url).to_return(:status => 404)
              end

              it "returns 400 without importing"
            end
          end

          context "when initiating server is not discoverable" do
            before do
              ##
              # Stub discovery
              http_stubs << stub_request(:head, remote_entity_url).to_return(:status => 200)
              http_stubs << stub_request(:get, remote_entity_url).to_return(:status => 404)
            end

            it "returns 400 without importing"
          end
        end

        context "without linked credentials post" do
          it "returns 400 without importing"
        end
      end

      context "when anything else" do
        it "returns 403 without importing"
      end
    end
  end
end
