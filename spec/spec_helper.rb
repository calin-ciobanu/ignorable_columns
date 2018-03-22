require 'active_record'
require 'rspec/expectations'

puts "Testing Against ActiveRecord #{ActiveRecord::VERSION::STRING}"

RSpec::Matchers.define :include_col_in_sql do |table, column|
  match do |actual|
    raw_explanation = actual.call.explain
    @select_queries = raw_explanation.split("\n").select do |line|
      line.include?('EXPLAIN for:') &&
        (line.include?("\"#{table}\".\"#{column}\"") || line.include?("\"#{table}\".*"))
    end
    @select_queries.present?
  end

  failure_message do |actual|
    "expected that #{actual} would contain column #{column} from table #{table}. Queries were: #{@select_queries}"
  end

  def supports_block_expectations?
    true
  end
end

ActiveRecord::Base.establish_connection('adapter' => 'sqlite3', 'database' => ':memory:')

require File.expand_path('../../lib/ignorable_columns.rb', __FILE__)
