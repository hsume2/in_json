require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class User < ActiveRecord::Base
  has_many :posts
  has_many :blog_posts
  has_many :check_ins
  has_many :reviews, :as => :reviewable

  in_json do
    name
    email
  end

  in_json(:with_post_count) do
    name
    email
    post_count
  end

  in_json(:with_posts) do
    post_count
    posts
  end

  in_json(:with_posts_nested) do
    posts do
      title
      content
    end
  end

  in_json(:with_posts_named) do
    posts :only_content
  end

  in_json(:with_posts_and_comments) do
    posts do
      title
      comments do
        content
      end
    end
  end

  in_json(:with_posts_and_comments_named) do
    posts do
      title
      comments :only_approved
    end
  end

  def post_count
    self.posts.count
  end
end

class Post < ActiveRecord::Base
  belongs_to :user
  has_many :comments
  has_many :reviews, :as => :reviewable

  in_json do
    title
  end

  in_json(:only_content) do
    content
  end
end

class BlogPost < Post
end

class Comment < ActiveRecord::Base
  belongs_to :post

  in_json(:only_approved) do
    approved
  end
end

describe InJson do
  before do
    @user = User.create(:name => "John User", :email => "john@example.com")
    @post = @user.posts.create(:title => "Hello World!", :content => "Welcome to my blog.")
    @blog_post = @user.blog_posts.create(:title => "Hello World!", :content => "Welcome to my blog post.")
    @comment = @post.comments.create(:content => "Great blog!", :approved => true)
  end

  it "should return model in json (default)" do
    @user.in_json.should == {
      :name => 'John User',
      :email => 'john@example.com'
    }
  end

  it "should return model in json without definition (default)" do
    @user.in_json(:missing_def).should == {
      :name => 'John User',
      :email => 'john@example.com'
    }
  end

  it "should return model in json with post count" do
    @user.in_json(:with_post_count).should == {
      :name => 'John User',
      :email => 'john@example.com',
      :post_count => 2
    }
  end

  it "should return model in json with posts" do
    @user.in_json(:with_posts).should == {
      :post_count => 2,
      :posts => [
        { :title => 'Hello World!' },
        { :title => 'Hello World!' }
      ]
    }
  end

  it "should return model in json with posts and nested definition" do
    @user.in_json(:with_posts_nested).should == {
      :posts => [
        { :title => 'Hello World!', :content => 'Welcome to my blog.' },
        { :title => 'Hello World!', :content => 'Welcome to my blog post.' }
      ]
    }
  end

  it "should return model in json with posts and named definition" do
    @user.in_json(:with_posts_named).should == {
      :posts => [
        { :content => 'Welcome to my blog.' },
        { :content => 'Welcome to my blog post.' }
      ]
    }
  end

  it "should return model in json with posts and comments" do
    @user.in_json(:with_posts_and_comments).should == {
      :posts => [
        { :title => 'Hello World!', :comments=>[{:content=>"Great blog!"}] },
        { :title => 'Hello World!', :comments=>[] }
      ]
    }
  end

  it "should return model in json with posts and comments named" do
    @user.in_json(:with_posts_and_comments_named).should == {
      :posts => [
        { :title => 'Hello World!', :comments=>[{:approved=>true}] },
        { :title => 'Hello World!', :comments=>[] }
      ]
    }
  end

  it "should use eager-loaded associations" do
    lambda {  @user = User.find(:first, :include => { :posts => :comments })  }.should have_queries(3)

    lambda {
      @user.in_json(:with_posts_and_comments).should == {
        :posts => [
          { :title => 'Hello World!', :comments=>[{:content=>"Great blog!"}] },
          { :title => 'Hello World!', :comments=>[] }
        ]
      }
    }.should have_queries(0)
  end

  it "should use eager-loaded associations on collection" do
    user = User.create(:name => "John User", :email => "john@example.com")
    post = user.posts.create(:title => "Hello World!", :content => "Welcome to my blog.")

    lambda {  @users = User.find(:all, :include => { :posts => :comments })  }.should have_queries(3)
    lambda {
      @users.in_json(:with_posts_and_comments).should == [{
        :posts => [
          { :title => 'Hello World!', :comments=>[{:content=>"Great blog!"}] },
          { :title => 'Hello World!', :comments=>[] }
        ]
      },
      {
        :posts => [
          { :title => 'Hello World!', :comments=>[] }
        ]
      }]
    }.should have_queries(0)
  end

  it "should return model as json" do
    @user_hash = JSON.parse(@user.to_json)
    @user_hash['name'].should == 'John User'
    @user_hash['email'].should == 'john@example.com'
  end

  it "should return collection as json" do
    user = User.create(:name => "User John", :email => "example@john.com")
    post = user.posts.create(:title => "Hello World!", :content => "Welcome to my blog.")
    @users = User.find(:all, :include => { :posts => :comments })

    @users_hash = JSON.parse(@users.to_json)
    @users_hash.tap do |h|
      h.size.should == 2
      h[0].tap do |u|
        u['name'].should == 'John User'
        u['email'].should == 'john@example.com'
      end
      h[1].tap do |u|
        u['name'].should == 'User John'
        u['email'].should == 'example@john.com'
      end
    end
  end
end
