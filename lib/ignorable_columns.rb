require 'active_record'
require 'active_support/core_ext/class/attribute'

module IgnorableColumns
  module InstanceMethods
    def attributes # :nodoc:
      if self.class.include_columns?
        super.reject { |col, _val| self.class.ignored_column?(col) && !self.class.included_columns.include?(col) }
      else
        super.reject { |col, _val| self.class.ignored_column?(col) }
      end
    end

    def attribute_names # :nodoc:
      if self.class.include_columns?
        super.reject { |col| self.class.ignored_column?(col) && !self.class.included_columns.include?(col) }
      else
        super.reject { |col| self.class.ignored_column?(col) }
      end
    end
  end

  module ClassMethods
    # Prevent Rails from loading a table column.
    # Useful for legacy database schemas with problematic column names,
    # like 'class' or 'attributes'.
    #
    #   class Topic < ActiveRecord::Base
    #     ignore_columns :attributes, :class
    #   end
    #
    #   Topic.new.respond_to?(:attributes) => false
    def ignore_columns(*cols)
      self.ignored_columns ||= []
      self.ignored_columns += (cols || []).map(&:to_s)
      self.ignored_columns.tap(&:uniq!)
      reset_columns
      columns
    end
    alias ignore_column ignore_columns

    # Ignore columns for select statements.
    # Useful for optimizing queries that load large amounts of rarely data.
    # Exclude ignored columns from the sql queries.
    # NOTE: should be called after #ignore_columns
    #
    #   class Topic < ActiveRecord::Base
    #     ignore_columns :attributes, :class
    #     ignore_columns_in_sql
    #   end
    def ignore_columns_in_sql
      @orig_default_scopes ||= default_scopes
      self.default_scopes = @orig_default_scopes and return unless ignored_columns.present?
      default_scope { select(*(all_columns.map(&:name) - ignored_columns)) }
    end
    alias ignore_column_in_sql ignore_columns_in_sql

    # Has a column been ignored?
    # Accepts both ActiveRecord::ConnectionAdapter::Column objects,
    # and actual column names ('title')
    def ignored_column?(column)
      self.ignored_columns.present? && self.ignored_columns.include?(
        column.respond_to?(:name) ? column.name : column.to_s
      )
    end

    # Execute block in a scope including all or some of the ignored columns.
    # If no arguments are passed all ignored columns will be included, otherwise
    # only the subset passed as argument will be included.
    #
    #   class Topic < ActiveRecord::Base
    #     ignore_columns :attributes, :class
    #     ignore_columns_in_sql
    #   end
    #   ...
    #   Topic.including_ignored_columns { Topic.last(5).map(&:attributes) }
    #   Topic.including_ignored_columns(:class) { Topic.last(5).map(&:attributes) }
    def including_ignored_columns(*cols)
      mutex.synchronize do
        begin
          toggle_columns true, cols
          yield
        ensure
          toggle_columns false
        end
      end
    end

    def columns # :nodoc:
      if @all_columns
        @columns ||= super.reject { |col| ignored_column?(col) }
      else
        @all_columns = super
        @columns = super.reject { |col| ignored_column?(col) }
      end
    end

    def column_names # :nodoc:
      if @all_column_names
        @column_names ||= @all_column_names.reject { |col| ignored_column?(col) }
      else
        @all_column_names = all_columns.map(&:name)
        @column_names = @all_column_names.reject { |col| ignored_column?(col) }
      end
    end

    def include_columns? # :nodoc:
      @include_columns
    end

    def included_columns # :nodoc:
      @included_columns
    end

    private

    def all_columns
      columns unless @all_columns
      @all_columns
    end

    def all_column_names
      column_names unless @all_column_names
      @all_column_names
    end

    def orig_default_scopes
      @orig_default_scopes || []
    end

    def init_columns(col_names = nil)
      reset_columns
      @columns = col_names.nil? ? all_columns : all_columns.select { |c| col_names.include? c.name }
      @column_names = col_names.nil? ? all_column_names : all_column_names.select { |cn| col_names.include? cn }
    end

    def reset_columns
      reset_column_information
      descendants.each(&:reset_column_information)
      @columns = nil
      @column_names = nil
    end

    def toggle_columns(on, cols = [])
      cols = cols.map(&:to_s)
      if on
        reset_columns
        filtered_columns = columns
        @included_columns = (ignored_columns & cols if cols.present?)
        @included_columns ||= ignored_columns || []
        new_column_names = filtered_columns.map(&:name) + @included_columns
        init_columns(new_column_names)
        self.default_scopes = orig_default_scopes
        default_scope { select(*new_column_names) }
        @include_columns = true
      else
        @include_columns = false
        reset_columns
        self.default_scopes = orig_default_scopes
        ignore_columns_in_sql
      end
    end

    def mutex
      @mutex ||= Mutex.new
    end
  end

  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
    base.send :class_attribute, :ignored_columns
  end
end

ActiveRecord::Base.send(:include, IgnorableColumns) unless ActiveRecord::Base.include?(IgnorableColumns::InstanceMethods)
