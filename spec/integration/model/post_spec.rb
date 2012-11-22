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

        def push(item)
          (@items ||= []) << item
        end
      end

      let(:subscribed_follower) { Fabricate(:follower, :entity => 'https://johnsmith.example.com') }
      let(:other_follower) { Fabricate(:follower, :entity => 'https://marks.example.com') }
      let(:entity_url) { 'https://alexdoe.example.org' }

      let(:post_attributes) do
        post_attrs = Fabricate.build(:post).attributes
        post_attrs.delete(:id)
        post_attrs.delete(:public_id)
        post_attrs.delete(:user_id)
        post_attrs
      end

      it "should create post version" do
        post_attrs = post_attributes.merge(
          :mentions => [
            { :entity => entity_url }
          ]
        )

        post = nil
        expect(lambda {
          expect(lambda {
            expect(lambda {
              post = described_class.create(post_attrs)
            }).to change(described_class, :count).by(1)
          }).to change(TentD::Model::PostVersion, :count).by(1)
        }).to change(TentD::Model::Mention, :count).by(1)

        expect(post.mentions_dataset.count).to eql(1)
        expect(post.latest_version.mentions_dataset.count).to eql(1)
      end

      it "should divide published_at by 1000 if it's in miliseconds" do
        post_attrs = post_attributes.merge(
          :published_at => Time.at(1349471384657),
        )
        post = described_class.create(post_attrs)
        expect(post.published_at.to_time.to_i).to eql(1349471384)
      end


      it 'should send notification to all mentioned entities not already subscribed' do
        post_type = 'https://tent.io/types/post/status/v0.1.0'
        post_attrs = post_attributes.merge(
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
          expect(returned_post).to eql(post)
        end

      end

      context 'when has permission via group' do
        before do
          TentD::Model::Permission.create(:group => group, :post => post)
          current_auth.groups = [group.public_id]
          current_auth.save
        end

        it 'should return post' do
          returned_post = described_class.find_with_permissions(post.id, current_auth)
          expect(returned_post).to eql(post)
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
      p.save
      expect(p.type_version).to eql('0.1.0')

      p.update type_version: '0.1.0'

      p = TentD::Model::Post.first(:id => p.id)


      p.type = 'http://mytype.io/v0.3.0'
      p.save
      expect(p.type_version).to eql('0.3.0')
    end
  end

  describe 'fetch_all' do
    context 'when requested post types specifically allowed' do
      it 'should return posts matching requested and allowed post types' do
        status_type = 'https://tent.io/types/post/status/v0.1.0'
        essay_type = 'https://tent.io/types/post/essay/v0.1.0'
        status_post = Fabricate(:post, :type => status_type, :public => false)
        essay_post = Fabricate(:post, :type => essay_type, :public => false)
        params = Hashie::Mash.new(
          :post_types => [status_type, essay_type].join(',')
        )
        current_auth = Hashie::Mash.new(
          :post_types => [status_type]
        )
        res = TentD::Model::Post.fetch_all(params, current_auth)
        expect(res.size).to eq(1)
        expect(res.first.id).to eq(status_post.id)
      end

      it 'should return all posts matching requested types if public' do
        status_type = 'https://tent.io/types/post/status/v0.1.0'
        essay_type = 'https://tent.io/types/post/essay/v0.1.0'
        status_post = Fabricate(:post, :type => status_type, :public => true)
        essay_post = Fabricate(:post, :type => essay_type, :public => true)
        params = Hashie::Mash.new(
          :post_types => [status_type, essay_type].join(',')
        )
        current_auth = Hashie::Mash.new(
          :post_types => [status_type]
        )
        res = TentD::Model::Post.fetch_all(params, current_auth)
        expect(res.size).to eq(2)
        expect(res.map(&:id).sort).to eq([status_post.id, essay_post.id].sort)
      end
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

      it 'should order by received_at desc' do
        TentD::Model::Post.destroy
        latest_post = Fabricate(:post, :public => !create_permissions, :received_at => Time.at(Time.now.to_i+86400)) # 1.day.from_now
        first_post = Fabricate(:post, :public => !create_permissions, :received_at => Time.at(Time.now.to_i-86400)) # 1.day.ago

        if create_permissions
          [first_post, latest_post].each { |post| @authorize_post.call(post) }
        end

        returned_post = described_class.fetch_with_permissions(params, current_auth)
        expect(returned_post.map(&:public_id)).to eql([latest_post.public_id, first_post.public_id])
      end

      context '[:since_id]' do
        it 'should only return posts with ids > :since_id' do
          TentD::Model::Post.destroy
          since_post = Fabricate(:post, :public => !create_permissions)
          post = Fabricate(:post, :public => !create_permissions)

          if create_permissions
            [post, since_post].each { |post| @authorize_post.call(post) }
          end

          params['since_id'] = since_post.id

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts).to eql([post])
        end
      end

      context '[:before_id]' do
        it 'should only return posts with ids < :before_id' do
          TentD::Model::Post.destroy
          post = Fabricate(:post, :public => !create_permissions)
          before_post = Fabricate(:post, :public => !create_permissions)

          if create_permissions
            [post, before_post].each { |post| @authorize_post.call(post) }
          end

          params['before_id'] = before_post.id

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts).to eql([post])
        end
      end

      context '[:since_time]' do
        it 'should only return posts with received_at > :since_time' do
          TentD::Model::Post.destroy
          since_post = Fabricate(:post, :public => !create_permissions,
                                 :received_at => Time.at(Time.now.to_i + (86400 * 10))) # 10.days.from_now
          post = Fabricate(:post, :public => !create_permissions,
                           :received_at => Time.at(Time.now.to_i + (86400 * 11))) # 11.days.from_now

          if create_permissions
            [post, since_post].each { |post| @authorize_post.call(post) }
          end

          params['since_time'] = since_post.received_at.to_time.to_i.to_s

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts).to eql([post])
        end

        context 'with [:order] = asc' do
          it 'should only return posts with received_at > :since_time in ascending order' do
            TentD::Model::Post.destroy
            since_post = Fabricate(:post, :public => !create_permissions,
                                   :received_at => Time.at(Time.now.to_i + (86400 * 10))) # 10.days.from_now
            post_a = Fabricate(:post, :public => !create_permissions,
                             :received_at => Time.at(Time.now.to_i + (86400 * 14))) # 14.days.from_now

            post_b = Fabricate(:post, :public => !create_permissions,
                             :received_at => Time.at(Time.now.to_i + (86400 * 11))) # 11.days.from_now

            if create_permissions
              [post_a, post_b, since_post].each { |post| @authorize_post.call(post) }
            end

            params['since_time'] = since_post.received_at.to_time.to_i.to_s
            params['limit'] = 1
            params['order'] = 'asc'

            returned_posts = described_class.fetch_with_permissions(params, current_auth)
            expect(returned_posts).to eql([post_b])
          end
        end

        context 'with [:sort_by] = published_at' do
          it 'should only return posts with published_at > :since_time' do
            TentD::Model::Post.destroy
            since_post = Fabricate(:post, :public => !create_permissions,
                                   :published_at => Time.at(Time.now.to_i + (86400 * 10))) # 10.days.from_now
            post = Fabricate(:post, :public => !create_permissions,
                             :published_at => Time.at(Time.now.to_i + (86400 * 11))) # 11.days.from_now

            if create_permissions
              [post, since_post].each { |post| @authorize_post.call(post) }
            end

            params['since_time'] = since_post.published_at.to_time.to_i.to_s
            params['sort_by'] = 'published_at'

            returned_posts = described_class.fetch_with_permissions(params, current_auth)
            expect(returned_posts).to eql([post])
          end
        end
      end

      context '[:before_time]' do
        it 'should only return posts with received_at < :before_time' do
          TentD::Model::Post.destroy
          post = Fabricate(:post, :public => !create_permissions,
                           :received_at => Time.at(Time.now.to_i - (86400 * 10))) # 10.days.ago
          before_post = Fabricate(:post, :public => !create_permissions,
                                  :received_at => Time.at(Time.now.to_i - (86400 * 9))) # 9.days.ago

          if create_permissions
            [post, before_post].each { |post| @authorize_post.call(post) }
          end

          params['before_time'] = before_post.received_at.to_time.to_i.to_s

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts).to eql([post])
        end

        context 'with [:sort_by] = published_at' do
          it 'should only return posts with published_at < :before_time' do
            TentD::Model::Post.destroy
            post = Fabricate(:post, :public => !create_permissions,
                             :published_at => Time.at(Time.now.to_i - (86400 * 10))) # 10.days.ago
            before_post = Fabricate(:post, :public => !create_permissions,
                                    :published_at => Time.at(Time.now.to_i - (86400 * 9))) # 9.days.ago

            if create_permissions
              [post, before_post].each { |post| @authorize_post.call(post) }
            end

            params['before_time'] = before_post.published_at.to_time.to_i.to_s
            params['sort_by'] = 'published_at'

            returned_posts = described_class.fetch_with_permissions(params, current_auth)
            expect(returned_posts).to eql([post])
          end
        end
      end

      context '[:post_types]' do
        it 'should only return posts type in :post_types' do
          TentD::Model::Post.destroy
          photo_post = Fabricate(:post, :public => !create_permissions, :type_base => "https://tent.io/types/post/photo")
          blog_post = Fabricate(:post, :public => !create_permissions, :type_base => "https://tent.io/types/post/blog")
          status_post = Fabricate(:post, :public => !create_permissions, :type_base => "https://tent.io/types/post/status")

          if create_permissions
            [photo_post, blog_post, status_post].each { |post| @authorize_post.call(post) }
          end

          params['post_types'] = [blog_post, photo_post].map { |p| URI.escape(p.type.uri, "://") }.join(',')

          returned_posts = described_class.fetch_with_permissions(params, current_auth)
          expect(returned_posts.size).to eql(2)
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
          expect(returned_posts.size).to eql(limit)
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
            expect(returned_posts.size).to eql(0)
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
            expect(returned_posts.size).to eql(limit)
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

    post = described_class.create(attributes)
    post = described_class.first(:id => post.id)
    attributes.each_pair do |k,v|
      if k == :type
        actual_value = post.type.uri
      else
        actual_value = post.send(k)
      end
      expect(actual_value).to eql(v)
    end
  end

  describe "#as_json" do
    let(:post) { Fabricate(:post) }

    let(:public_attributes) do
      {
        :id => post.public_id,
        :version => post.is_a?(TentD::Model::Post) ? post.latest_version(:fields => [:version]).version : post.version,
        :entity => post.entity,
        :type => post.type.uri,
        :licenses => post.licenses,
        :content => post.content,
        :mentions => [],
        :app => { :url => post.app_url, :name => post.app_name },
        :attachments => [],
        :permissions => { :public => post.public },
        :published_at => post.published_at.to_time.to_i
      }
    end

    examples = proc do
      it "should replace id with public_id" do
        expect(post.as_json[:id]).to eql(post.public_id)
        expect(post.as_json).to_not have_key(:public_id)
      end

      it "should not add id to returned object if excluded" do
        expect(post.as_json(:exclude => :id)).to_not have_key(:id)
      end

      context 'without options' do
        it 'should only return public attributes' do
          expect(post.as_json).to eql(public_attributes)
        end
      end

      context 'with options[:permissions] = true' do
        let(:follower) { Fabricate(:follower) }
        let(:group) { Fabricate(:group) }
        let(:post) { Fabricate(:post) }
        let!(:entity_permission) { Fabricate(:permission, :follower_access => follower, :post => post) }
        let!(:group_permission) { Fabricate(:permission, :group => group, :post => post) }

        it 'should return detailed permissions' do
          expect(post.as_json(:permissions => true)).to eql(public_attributes.merge(
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
          post.following = Fabricate(:following)
          expect(post.as_json(:app => true)).to eql(public_attributes.merge(
            :received_at => post.received_at.to_time.to_i,
            :updated_at => post.updated_at.to_time.to_i,
            :published_at => post.published_at.to_time.to_i,
          ))
        end
      end

      context 'with options[:exclude]' do
        it 'should return public attributes excluding specified keys' do
          expected_attributes = public_attributes.dup
          expected_attributes.delete(:published_at)
          expect(post.as_json(:exclude => [:published_at])).to eql(expected_attributes)
        end
      end

      context 'with options[:view]' do
        it 'should return content keys specified by view' do
          post.update(:views => {
            'foo' => {
              'content' => [
                'foo/bar'
              ]
            },
            'bar' => {
              'content' => ['baz', 'foo']
            }
          }, :content => {
            'foo' => { 'bar' => { 'baz' => 'ChunkyBacon' } },
            'baz' => 'FooBar'
          })

          expect(post.as_json(:view => 'foo')).to eql(public_attributes.merge(
            :content => {
              'bar' => { 'baz' => 'ChunkyBacon' }
            }
          ))

          expect(post.as_json(:view => 'bar')).to eql(public_attributes.merge(
            :content => {
              'foo' => { 'bar' => { 'baz' => 'ChunkyBacon' } },
              'baz' => 'FooBar'
            }
          ))

          expect(post.as_json(:view => 'full')).to eql(public_attributes)

          expected_attributes = public_attributes.dup
          expected_attributes.delete(:content)
          expected_attributes.delete(:attachments)
          expect(post.as_json(:view => 'meta')).to eql(expected_attributes)
        end

        it 'should filter attachments' do
          first_attachment = nil
          other_attachment = nil

          expect(lambda {
            if post.kind_of?(TentD::Model::PostVersion)
              base_attrs = {}
            else
              base_attrs = {
                :post_id => post.id
              }
            end

            first_attachment = Fabricate(:post_attachment, base_attrs.merge(
                                         :category => 'foo',
                                         :type => 'text/plain',
                                         :name => 'foobar.txt',
                                         :data => 'Chunky Bacon',
                                         :size => 4))
            other_attachment = Fabricate(:post_attachment, base_attrs.merge(
                                         :category => 'bar',
                                         :type => 'application/javascript',
                                         :name => 'barbaz.js',
                                         :data => 'alert("Chunky Bacon")',
                                         :size => 8))

            if post.kind_of?(TentD::Model::PostVersion)
              [first_attachment, other_attachment].each do |a|
                post.db[:post_versions_attachments].insert(
                  :post_attachment_id => a.id,
                  :post_version_id => post.id
                )
              end
            end
          }).to change(post.attachments_dataset, :count).by(2)

          post.update(:views => {
            'foo' => {
              'attachments' => [ { 'category' => 'foo' } ]
            },
            'text' => {
              'attachments' => [{ 'type' => 'text/plain' }]
            },
            'foobar' => {
              'attachments' => [{ 'name' => 'foobar.txt' }]
            },
            'foojs' => {
              'attachments' => [{ 'type' => 'application/javascript' }, { 'category' => 'foo' }]
            },
            'nothing' => {
              'attachments' => [{ 'type' => 'text/plain', 'category' => 'bar' }]
            },
            'invalid' => {
              'attachments' => [{ 'id' => first_attachment.id }, { 'category' => 'bar' }]
            }
          }, :content => {
            'foo' => { 'bar' => { 'baz' => 'ChunkyBacon' } },
            'baz' => 'FooBar'
          })

          expect(post.as_json(:view => 'foo')).to eql(public_attributes.merge(
            :attachments => [first_attachment],
            :content => {}
          ))

          expect(post.as_json(:view => 'text')).to eql(public_attributes.merge(
            :attachments => [first_attachment],
            :content => {}
          ))

          expect(post.as_json(:view => 'foobar')).to eql(public_attributes.merge(
            :attachments => [first_attachment],
            :content => {}
          ))

          expect(post.as_json(:view => 'foojs')).to eql(public_attributes.merge(
            :attachments => [first_attachment, other_attachment],
            :content => {}
          ))

          expect(post.as_json(:view => 'nothing')).to eql(public_attributes.merge(
            :attachments => [],
            :content => {}
          ))

          expect(post.as_json(:view => 'invalid')).to eql(public_attributes.merge(
            :attachments => [other_attachment],
            :content => {}
          ))

          expected = public_attributes
          expected.delete(:attachments)
          res = post.as_json(:view => 'full')
          attachments = res.delete(:attachments)
          expect(attachments.sort_by { |a| a[:id] }).to eql([first_attachment.as_json, other_attachment.as_json].sort_by { |a| a[:id] })
          expect(res).to eql(expected)

          expected_attributes = public_attributes.dup
          expected_attributes.delete(:content)
          expected_attributes.delete(:attachments)
          expect(post.as_json(:view => 'meta')).to eql(expected_attributes)
        end
      end
    end

    context &examples

    context 'PostVersion' do
      let(:post) { Fabricate(:post).latest_version }

      context &examples
    end
  end

  it "should generate public_id on create" do
    post = Fabricate.build(:post)
    expect(post.save).to be_true
    expect(post.public_id).to_not be_nil
  end

  xit "should ensure public_id is unique" do
    first_post = Fabricate(:post)
    post = Fabricate.build(:post, :public_id => first_post.public_id)
    post.save
    expect(post).to be_saved
    expect(post.public_id).to_not eql(first_post.public_id)
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
        let(:follower) { Fabricate(:follower, :groups => [Fabricate(:group).public_id]) }

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

    context "with following" do
      it "should be true for a public post" do
        expect(post.can_notify?(Fabricate(:following))).to be_true
      end

      context "with private post" do
        let(:post) { Fabricate(:post, :public => false) }
        let(:following) { Fabricate(:following, :groups => [Fabricate(:group).public_id]) }

        it "should be true for permission group" do
          Fabricate(:permission, :group_public_id => following.groups.first, :post_id => post.id)
          expect(post.can_notify?(following)).to be_true
        end

        it "should be true for explicit permission" do
          Fabricate(:permission, :following => following, :post_id => post.id)
          expect(post.can_notify?(following)).to be_true
        end

        it "should be false if unauthorized" do
          expect(post.can_notify?(following)).to be_false
        end
      end
    end
  end
end

