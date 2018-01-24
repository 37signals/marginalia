#!/usr/bin/env rake
require "bundler/gem_tasks"

task :default => ['test:postgresql']

namespace :test do
  desc "test PostgreSQL driver"
  task :postgresql do
    sh "DRIVER=postgresql DB_USERNAME=postgres ruby -Ilib -Itest test/*_test.rb"
  end
end

namespace :db do
  desc "reset all databases"
  task :reset => [:"postgresql:reset"]

  namespace :postgresql do
    desc "reset PostgreSQL database"
    task :reset => [:drop, :create]

    desc "create PostgreSQL database"
    task :create do
      sh 'createdb -U postgres marginalia_test'
    end

    desc "drop PostgreSQL database"
    task :drop do
      sh 'psql -d postgres -U postgres -c "DROP DATABASE IF EXISTS marginalia_test"'
    end
  end
end
