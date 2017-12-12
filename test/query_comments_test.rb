# -*- coding: utf-8 -*-

def adapter_pool_available?
  Gem::Version.new(ActiveRecord::VERSION::STRING) >= Gem::Version.new('3.2.19')
end

require "minitest/autorun"
require 'mocha/test_unit'
require 'logger'
require 'pp'
require 'active_record'

# Shim for compatibility with older versions of MiniTest
MiniTest::Test = MiniTest::Unit::TestCase unless defined?(MiniTest::Test)

# From version 4.1, ActiveRecord expects `Rails.env` to be
# defined if `Rails` is defined
if defined?(Rails) && !defined?(Rails.env)
  module Rails
    def self.env
    end
  end
end

require 'marginalia'
RAILS_ROOT = File.expand_path(File.dirname(__FILE__))

ActiveRecord::Base.establish_connection({
  :adapter  => ENV["DRIVER"] || "mysql",
  :host     => "localhost",
  :username => ENV["DB_USERNAME"] || "root",
  :database => "marginalia_test"
})

class Post < ActiveRecord::Base
end

unless Post.table_exists?
  ActiveRecord::Schema.define do
    create_table "posts", :force => true do |t|
    end
  end
end

Marginalia.install

class MarginaliaTest < MiniTest::Test
  def setup
    @queries = []
    ActiveSupport::Notifications.subscribe "sql.active_record" do |*args|
      @queries << args.last[:sql]
    end
    Marginalia.set('app', 'rails')
  end

  def test_double_annotate
    ActiveRecord::Base.connection.expects(:annotate_sql).returns("select id from posts").once
    ActiveRecord::Base.connection.send(:select, "select id from posts")
  ensure
    ActiveRecord::Base.connection.unstub(:annotate_sql)
  end

  def test_exists
    skip if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('3.2')
    Post.exists?
    assert_match %r{/\*app=rails\*/$}, @queries.last
  end

  def test_query_commenting_on_mysql_driver_with_no_action
    ActiveRecord::Base.connection.execute "select id from posts"
    assert_match %r{select id from posts /\*app=rails\*/$}, @queries.first
  end

  if ENV["DRIVER"] =~ /^mysql/
    def test_query_commenting_on_mysql_driver_with_binary_chars
      ActiveRecord::Base.connection.execute "select id from posts /* \x81\x80\u0010\ */"
      assert_equal "select id from posts /* \x81\x80\u0010 */ /*app=rails*/", @queries.first
    end
  end

  if ENV["DRIVER"] =~ /^postgres/
    def test_query_commenting_on_postgres_update
      ActiveRecord::Base.connection.expects(:annotate_sql).returns("update posts set id = 1").once
      ActiveRecord::Base.connection.send(:exec_update, "update posts set id = 1")
    ensure
      ActiveRecord::Base.connection.unstub(:annotate_sql)
    end

    def test_query_commenting_on_postgres_delete
      ActiveRecord::Base.connection.expects(:annotate_sql).returns("delete from posts where id = 1").once
      ActiveRecord::Base.connection.send(:exec_delete, "delete from posts where id = 1")
    ensure
      ActiveRecord::Base.connection.unstub(:annotate_sql)
    end
  end

  def test_configuring_application
    Marginalia.set('app', 'customapp')
    Post.all
    assert_match %r{/\*app=customapp\*/$}, @queries.first
  end

  def test_configuring_query_components
    Marginalia.set('controller', 'posts')
    Post.all
    assert_match %r{/\*app=rails,controller=posts\*/$}, @queries.first
  end

  def teardown
    Marginalia.clear!
    ActiveSupport::Notifications.unsubscribe "sql.active_record"
  end
end
