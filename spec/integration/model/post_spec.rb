require 'spec_helper'

describe TentServer::Model::Post do
  describe 'find_with_permissions(id, current_auth)' do
    shared_examples 'current_auth param' do
      let(:group) { Fabricate(:group, :name => 'family') }
      let(:post) { Fabricate(:post, :public => false) }

      context 'when has permission via explicit' do
        before do
          case current_auth
          when TentServer::Model::Follower
            current_auth.access_permissions.create(:post_id => post.id)
          else
            current_auth.permissions.create(:post_id => post.id)
          end
        end

        it 'should return post' do
          returned_post = described_class.find_with_permissions(post.id, current_auth)
          expect(returned_post).to eq(post)
        end

      end

      context 'when has permission via group' do
        before do
          group.permissions.create(:post_id => post.id)
          current_auth.groups = [group.id]
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

    context 'when AppAuthorization' do
      let(:current_auth) { Fabricate(:app_authorization, :app => Fabricate(:app)) }

      it_behaves_like 'current_auth param'
    end
  end

  describe 'fetch_with_permissions(params, current_auth)' do
    let(:group) { Fabricate(:group, :name => 'friends') }
    let(:params) { Hash.new }

    with_params = proc do
      before do
        if current_auth && create_permissions == true
          @authorize_post = lambda { |post| TentServer::Model::Permission.create(:post_id => post.id, current_auth.permissible_foreign_key => current_auth.id) }
        end
      end

      context '[:since_id]' do
        it 'should only return posts with ids > :since_id' do
          TentServer::Model::Post.all.destroy!
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
          TentServer::Model::Post.all.destroy!
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
          TentServer::Model::Post.all.destroy!
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
          TentServer::Model::Post.all.destroy!
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
          TentServer::Model::Post.all.destroy!
          photo_post = Fabricate(:post, :public => !create_permissions, :type => URI("https://tent.io/types/posts/photo"))
          blog_post = Fabricate(:post, :public => !create_permissions, :type => URI("https://tent.io/types/posts/blog"))
          status_post = Fabricate(:post, :public => !create_permissions, :type => URI("https://tent.io/types/posts/status"))

          if create_permissions
            [photo_post, blog_post, status_post].each { |post| @authorize_post.call(post) }
          end

          params['post_types'] = [blog_post, photo_post].map { |p| URI.escape(p.type.to_s, "://") }.join(',')

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

        it 'should never return more than TentServer::API::MAX_PER_PAGE' do
          limit = 1
          posts = 0.upto(limit).map { Fabricate(:post, :public => !create_permissions) }

          if create_permissions
            posts.each { |post| @authorize_post.call(post) }
          end

          params['limit'] = limit.to_s

          with_constants "TentServer::API::MAX_PER_PAGE" => 0 do
            returned_posts = described_class.fetch_with_permissions(params, current_auth)
            expect(returned_posts.size).to eq(0)
          end
        end
      end

      context 'no [:limit]' do
        it 'should return TentServer::API::PER_PAGE number of posts' do
          with_constants "TentServer::API::PER_PAGE" => 1, "TentServer::API::MAX_PER_PAGE" => 2 do
            limit = TentServer::API::PER_PAGE
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
            TentServer::Model::Permission.create(:post_id => private_post.id, current_auth.permissible_foreign_key => current_auth.id)

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

      context 'when AppAuthorization' do
        let(:current_auth) { Fabricate(:app_authorization, :app => Fabricate(:app)) }
        context '', &current_auth_stuff
      end
    end
  end

  it "should persist with proper serialization" do
    attributes = {
      :entity => "https://example.org",
      :scope => :limited,
      :type => "https://tent.io/types/posts/status",
      :licenses => ["http://creativecommons.org/licenses/by-nc-sa/3.0/", "http://www.gnu.org/copyleft/gpl.html"],
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

