require "rubygems"
require "bundler/setup"
Bundler.require(:default)

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'rspec'
require 'in_json'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')

[:users, :posts, :comments].each do |table|
  ActiveRecord::Base.connection.drop_table table rescue nil
end

ActiveRecord::Base.connection.create_table :users do |t|
  t.string :name
  t.string :email
end

ActiveRecord::Base.connection.create_table :posts do |t|
  t.string :title
  t.text :content
  t.integer :user_id
  t.string :type
end

ActiveRecord::Base.connection.create_table :comments do |t|
  t.text :content
  t.boolean :approved
  t.integer :post_id
end

ActiveRecord::Base.connection.create_table :reviews do |t|
  t.integer :score
  t.integer :post_id
end

ActiveRecord::Base.connection.class.class_eval do
  IGNORED_SQL = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /SHOW FIELDS/]

  def execute_with_query_record(sql, name = nil, &block)
    $queries_executed ||= []
    $queries_executed << sql unless IGNORED_SQL.any? { |r| sql =~ r }
    execute_without_query_record(sql, name, &block)
  end

  alias_method_chain :execute, :query_record
end

module ActiveRecordQueriesMatcher
  class HaveQueries
    def initialize(num)
      @num = num
    end

    def matches?(target)
      begin
        $queries_executed = []
        target.call
        @num == $queries_executed.size
      ensure
        %w{ BEGIN COMMIT }.each { |x| $queries_executed.delete(x) }
      end
    end

    def failure_message_for_should
      "#{$queries_executed.size} instead of #{@num} queries were executed.#{$queries_executed.size == 0 ? '' : "\nQueries:\n#{$queries_executed.join("\n")}"}"
    end
  end

  def have_queries(num = 1)
    HaveQueries.new(num)
  end
end

require 'database_cleaner'

RSpec.configure do |config|
  config.include ActiveRecordQueriesMatcher
  
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.before(:each) do
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
end
