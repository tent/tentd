require 'spec_helper'

describe TentServer::Model::Post do
  it "should persist with proper serialization" do
    attributes = {
      :entity => "https://example.org",
      :scope => :limited,
      :type => "https://tent.io/types/posts/status",
      :licenses => ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"],
      :groups => ["friends", "family"],
      :recipients => ["https://smith.example.com", "https://alex.example.com"],
      :content => {
        "text" => "Voluptate nulla et similique sed dignissimos ea. Dignissimos sint reiciendis voluptas. Aliquid id qui nihil illum omnis. Explicabo ipsum non blanditiis aut aperiam enim ab."
      }
    }

    post = described_class.create!(attributes)
    post = described_class.get(post.id)
    attributes.each_pair do |k,v|
      actual_value = post.send(k)
      if actual_value.is_a? Addressable::URI
        actual_value = actual_value.to_s
      end
      expect(actual_value).to eq(v)
    end
  end
end

