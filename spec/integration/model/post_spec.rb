require 'spec_helper'

describe TentD::Model::Post do
  let(:http_stubs) { Faraday::Adapter::Test::Stubs.new }

  describe '.create(data)' do
    context 'when posted on behalf of this server (original)' do
      class TestNotificationQueue
        attr_accessor :items
        def initialize
          @items = []
        end

        def <<(item)
          (@items ||= []) << item
        end
      end

      let(:subscribed_follower) { Fabricate(:follower, :entity => 'https://johnsmith.example.com') }
      let(:other_follower) { Fabricate(:follower, :entity => 'https://marks.example.com') }
      let(:entity_url) { 'https://alexdoe.example.org' }

      it 'should send notification to all mentioned entities not already subscribed' do
        post_type = 'https://tent.io/types/post/status/v0.1.0'
        post_attrs = Fabricate.build(:post).attributes.merge(
          :type => post_type,
          :mentions => [
            { :entity => subscribed_follower.entity },
            { :entity => other_follower.entity },
            { :entity => entity_url },
          ]
        )

        notification_subscription = Fabricate(:notification_subscription, :follower => subscribed_follower, :type => post_type)
        queue = TestNotificationQueue.new
        with_constants "TentD::Notifications::NOTIFY_ENTITY_QUEUE" => queue do
          expect(lambda {
            described_class.create(post_attrs)
          }).to change(queue.items, :size).by(2)
        end
      end
    end
  end

  describe 'find_with_permissions(id, current_auth)' do
    shared_examples 'current_auth param' do
      let(:group) { Fabricate(:group, :name => 'family') }
      let(:post) { Fabricate(:post, :public => false) }

      context 'when has permission via explicit' do
        before do
          TentD::Model::Permission.create(
            :post_id => post.id,
            current_auth.permissible_foreign_key => current_auth.id
          )
        end

        it 'should return post' do
          returned_post = described_class.find_with_permissions(post.id, current_auth)
          expect(returned_post).to eq(post)
        end

      end

      context 'when has permission via group' do
        before do
          group.permissions.create(:post_id => post.id)
          current_auth.groups = [group.public_id]
          current_auth.save
        end

        it 'should return post' do
          returned_post = described_class.find_with_permissions(post.id, current_auth)
          expect(returned_post).to eq(post)
        end
      end

      context 'when does not have permission' do
        it 'should return nil' do
          returned_post = described_class.find_with_permissions(post.id, current_auth)
          expect(returned_post).to be_nil
        end
      end
    end

    context 'when Follower' do
      let(:current_auth) { Fabricate(:follower, :groups => []) }

      it_behaves_like 'current_auth param'
    end
  end

  describe 'changing type' do
    it 'updates the version and view' do
      p = Fabricate(:post)
      p.type = 'http://me.io/sometype/v0.1.0'
      p.save!
      expect(p.type_version).to eq('0.1.0')

      p.update type_version: '0.1.0'

      p = TentD::Model::Post.get(p.id)


      p.type = 'http://mytype.io/v0.3.0'
      p.save!
      expect(p.type_version).to eq('0.3.0')
    end
  end

  describe 'fetch_with_permissions(params, current_auth)' do
    let(:group) { Fabricate(:group, :name => 'friends') }
    let(:params) { Hash.new }

    with_params = proc do
      before do
        if current_auth && create_permissions == true
          @authorize_post = lambda { |post| TentD::Model::Permission.create(:post_id => post.id, current_auth.permissible_foreign_key => current_auth.id) }
        end
      end

      context '[:since_id]' do
        it 'should only return posts with ids > :since_id' do
          TentD::Model::Post.all.destroy!
          since_post = Fabricate(:post, :public => !create_permissions)
          post = Fabricate(:post, :public => !create_permissions)

          if create_permissions
            [post, since_post].each { |post| @authorize_post.call(post) }
          end

          params['since_id'] = since_post.id

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts).to eq([post])
        end
      end

      context '[:before_id]' do
        it 'should only return posts with ids < :before_id' do
          TentD::Model::Post.all.destroy!
          post = Fabricate(:post, :public => !create_permissions)
          before_post = Fabricate(:post, :public => !create_permissions)

          if create_permissions
            [post, before_post].each { |post| @authorize_post.call(post) }
          end

          params['before_id'] = before_post.id

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts).to eq([post])
        end
      end

      context '[:since_time]' do
        it 'should only return posts with published_at > :since_time' do
          TentD::Model::Post.all.destroy!
          since_post = Fabricate(:post, :public => !create_permissions,
                                 :published_at => Time.at(Time.now.to_i + (86400 * 10))) # 10.days.from_now
          post = Fabricate(:post, :public => !create_permissions,
                           :published_at => Time.at(Time.now.to_i + (86400 * 11))) # 11.days.from_now

          if create_permissions
            [post, since_post].each { |post| @authorize_post.call(post) }
          end

          params['since_time'] = since_post.published_at.to_time.to_i.to_s

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts).to eq([post])
        end
      end

      context '[:before_time]' do
        it 'should only return posts with published_at < :before_time' do
          TentD::Model::Post.all.destroy!
          post = Fabricate(:post, :public => !create_permissions,
                           :published_at => Time.at(Time.now.to_i - (86400 * 10))) # 10.days.ago
          before_post = Fabricate(:post, :public => !create_permissions,
                                  :published_at => Time.at(Time.now.to_i - (86400 * 9))) # 9.days.ago

          if create_permissions
            [post, before_post].each { |post| @authorize_post.call(post) }
          end

          params['before_time'] = before_post.published_at.to_time.to_i.to_s

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts).to eq([post])
        end
      end

      context '[:post_types]' do
        it 'should only return posts type in :post_types' do
          TentD::Model::Post.all.destroy!
          photo_post = Fabricate(:post, :public => !create_permissions, :type_base => "https://tent.io/types/post/photo")
          blog_post = Fabricate(:post, :public => !create_permissions, :type_base => "https://tent.io/types/post/blog")
          status_post = Fabricate(:post, :public => !create_permissions, :type_base => "https://tent.io/types/post/status")

          if create_permissions
            [photo_post, blog_post, status_post].each { |post| @authorize_post.call(post) }
          end

          params['post_types'] = [blog_post, photo_post].map { |p| URI.escape(p.type.uri, "://") }.join(',')

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts.size).to eq(2)
          expect(returned_posts).to include(photo_post)
          expect(returned_posts).to include(blog_post)
        end
      end

      context '[:limit]' do
        it 'should return at most :limit number of posts' do
          limit = 1
          posts = 0.upto(limit).map { Fabricate(:post, :public => !create_permissions) }

          if create_permissions
            posts.each { |post| @authorize_post.call(post) }
          end

          params['limit'] = limit.to_s

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts.size).to eq(limit)
        end

        it 'should never return more than TentD::API::MAX_PER_PAGE' do
          limit = 1
          posts = 0.upto(limit).map { Fabricate(:post, :public => !create_permissions) }

          if create_permissions
            posts.each { |post| @authorize_post.call(post) }
          end

          params['limit'] = limit.to_s

          with_constants "TentD::API::MAX_PER_PAGE" => 0 do
            returned_posts = described_class.fetch_with_permissions(params, current_auth)
            expect(returned_posts.size).to eq(0)
          end
        end
      end

      context 'no [:limit]' do
        it 'should return TentD::API::PER_PAGE number of posts' do
          with_constants "TentD::API::PER_PAGE" => 1, "TentD::API::MAX_PER_PAGE" => 2 do
            limit = TentD::API::PER_PAGE
            posts = 0.upto(limit+1).map { Fabricate(:post, :public => !create_permissions) }

            if create_permissions
              posts.each { |post| @authorize_post.call(post) }
            end

            returned_posts = described_class.fetch_with_permissions(params, current_auth)
            expect(returned_posts.size).to eq(limit)
          end
        end
      end
    end

    context 'without current_auth' do
      let(:current_auth) { nil }
      let(:create_permissions) { false }

      it 'should only fetch public posts' do
        private_post = Fabricate(:post, :public => false)
        public_post = Fabricate(:post, :public => true)
        returned_posts = described_class.fetch_with_permissions(params, nil)
        expect(returned_posts).to include(public_post)
        expect(returned_posts).to_not include(private_post)
      end

      context 'with params', &with_params
    end

    context 'with current_auth' do
      let(:create_permissions) { false }
      current_auth_stuff = proc do
        context 'with permission' do
          it 'should return private posts' do
            private_post = Fabricate(:post, :public => false)
            public_post = Fabricate(:post, :public => true)
            TentD::Model::Permission.create(:post_id => private_post.id, current_auth.permissible_foreign_key => current_auth.id)

            returned_posts = described_class.fetch_with_permissions(params, current_auth)
            expect(returned_posts).to include(private_post)
            expect(returned_posts).to include(public_post)
          end

          context 'with params' do
            context 'private posts' do
              let(:create_permissions) { true }
              context '', &with_params
            end

            context 'public posts', &with_params
          end
        end

        context 'without permission' do
          it 'should only return public posts' do
            private_post = Fabricate(:post, :public => false)
            public_post = Fabricate(:post, :public => true)

            returned_posts = described_class.fetch_with_permissions(params, current_auth)
            expect(returned_posts).to_not include(private_post)
            expect(returned_posts).to include(public_post)
          end

          context 'with params' do
            context '', &with_params
          end
        end
      end

      context 'when Follower' do
        let(:current_auth) { Fabricate(:follower) }
        context '', &current_auth_stuff
      end
    end
  end

  it "should persist with proper serialization" do
    attributes = {
      :entity => "https://example.org",
      :type_base => "https://tent.io/types/post/status",
      :type_version => "0.1.0",
      :licenses => ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"],
      :content => {
        "text" => "Voluptate nulla et similique sed dignissimos ea. Dignissimos sint reiciendis voluptas. Aliquid id qui nihil illum omnis. Explicabo ipsum non blanditiis aut aperiam enim ab."
      }
    }

    post = described_class.create!(attributes)
    post = described_class.get(post.id)
    attributes.each_pair do |k,v|
      if k == :type
        actual_value = post.type.uri
      else
        actual_value = post.send(k)
      end
      expect(actual_value).to eq(v)
    end
  end

  describe "#as_json" do
    let(:post) { Fabricate(:post) }
    let(:public_attributes) do
      {
        :id => post.public_id,
        :entity => post.entity,
        :type => post.type.uri,
        :licenses => post.licenses,
        :content => post.content,
        :app => { :url => post.app_url, :name => post.app_name },
        :attachments => [],
        :permissions => { :public => post.public },
        :published_at => post.published_at.to_time.to_i
      }
    end

    it "should replace id with public_id" do
      expect(post.as_json[:id]).to eq(post.public_id)
      expect(post.as_json).to_not have_key(:public_id)
    end

    it "should not add id to returned object if excluded" do
      expect(post.as_json(:exclude => :id)).to_not have_key(:id)
    end

    context 'without options' do
      it 'should only return public attributes' do
        expect(post.as_json).to eq(public_attributes)
      end
    end

    context 'with options[:permissions] = true' do
      let(:follower) { Fabricate(:follower) }
      let(:group) { Fabricate(:group) }
      let(:entity_permission) { Fabricate(:permission, :follower_access => follower) }
      let(:group_permission) { Fabricate(:permission, :group => group) }
      let(:post) { Fabricate(:post, :permissions => [entity_permission, group_permission]) }

      it 'should return detailed permissions' do
        expect(post.as_json(:permissions => true)).to eq(public_attributes.merge(
          :permissions => {
            :public => post.public,
            :groups => [group.public_id],
            :entities => {
              follower.entity => true
            }
          }
        ))
      end
    end

    context 'with options[:app] = true' do
      it 'should return app relevant data' do
        expect(post.as_json(:app => true)).to eq(public_attributes.merge(
          :received_at => post.received_at.to_time.to_i,
          :updated_at => post.updated_at.to_time.to_i,
          :published_at => post.published_at.to_time.to_i,
          :known_entity => post.known_entity
        ))
      end
    end

    context 'with options[:exclude]' do
      it 'should return public attributes excluding specified keys' do
        expected_attributes = public_attributes.dup
        expected_attributes.delete(:published_at)
        expect(post.as_json(:exclude => [:published_at])).to eq(expected_attributes)
      end
    end
  end

  it "should generate public_id on create" do
    post = Fabricate.build(:post)
    expect(post.save).to be_true
    expect(post.public_id).to_not be_nil
  end

  it "should ensure public_id is unique" do
    first_post = Fabricate(:post)
    post = Fabricate.build(:post, :public_id => first_post.public_id)
    post.save
    expect(post).to be_saved
    expect(post.public_id).to_not eq(first_post.public_id)
  end

  describe "can_notify?" do
    let(:post) { Fabricate.build(:post) }

    context "with app authorization" do
      it "should be true for a public post" do
        expect(post.can_notify?(Fabricate(:app_authorization, :app => Fabricate(:app)))).to be_true
      end

      describe "with private post" do
        let(:post) { Fabricate.build(:post, :public => false) }

        it "should be true with read_posts scope" do
          auth = Fabricate.build(:app_authorization, :scopes => [:read_posts])
          expect(post.can_notify?(auth)).to be_true
        end

        it "should be true with authorized type" do
          auth = Fabricate.build(:app_authorization, :post_types => [post.type.base])
          expect(post.can_notify?(auth)).to be_true
        end

        it "should be false if unauthorized" do
          auth = Fabricate.build(:app_authorization)
          expect(post.can_notify?(auth)).to be_false
        end
      end
    end

    context "with follower" do
      it "should be true for a public post" do
        expect(post.can_notify?(Fabricate(:follower))).to be_true
      end

      describe "with private post" do
        let(:post) { Fabricate(:post, :public => false) }
        let(:follower) { Fabricate(:follower) }

        it "should be true for permission group" do
          TentD::Model::Permission.create(:group_public_id => follower.groups.first, :post_id => post.id)
          expect(post.can_notify?(follower)).to be_true
        end

        it "should be true for explicit permission" do
          TentD::Model::Permission.create(:follower_access_id => follower.id, :post_id => post.id)
          expect(post.can_notify?(follower)).to be_true
        end

        it "should be false if unauthorized" do
          expect(post.can_notify?(follower)).to be_false
        end
      end
    end
  end
end

