require 'active_record'
require 'active_support/core_ext/class/attribute'

module IgnorableColumns
  module InstanceMethods
    def attributes # :nodoc:
      return super unless self.class.ignorable_columns
      @attributes ||= self.class.attributes
      byebug
      @attributes.to_hash.reject { |col, _val| self.class.ignored_column?(col) }
    end

    def attribute_names # :nodoc:
      return super unless self.class.ignorable_columns
      super.reject { |col| self.class.ignored_column?(col) }
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
      self.ignorable_columns ||= []
      self.ignorable_columns += (cols || []).map(&:to_s)
      self.ignorable_columns.tap(&:uniq!)
      reset_columns
      columns
      if @all_attributes
        @attributes ||= ActiveModel::AttributeSet.new(
          @all_attributes.except(
            *(ignorable_columns - (included_columns || [])))
        )
      else
        @all_attributes = @default_attributes
        @default_attributes = @attributes = ActiveModel::AttributeSet.new(
          @all_attributes.except(
            *(ignorable_columns - (included_columns || [])))
        )
      end
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
      (self.default_scopes = orig_default_scopes) && return unless ignorable_columns.present?
      unless default_scopes.include? default_scopes_cache[ignorable_columns]
        default_scopes_cache[ignorable_columns] ||= proc { select(*(all_columns.map(&:name) - ignorable_columns)) }
        self.default_scopes = (default_scopes.clone || []) << default_scopes_cache[ignorable_columns]
      end
    end
    alias ignore_column_in_sql ignore_columns_in_sql

    # Has a column been ignored?
    # Accepts both ActiveRecord::ConnectionAdapter::Column objects,
    # and actual column names ('title')
    def ignored_column?(column)
      matcher = column.respond_to?(:name) ? column.name : column.to_s
      self.ignorable_columns.present? &&
        !(self.included_columns && self.included_columns.include?(matcher)) &&
        self.ignorable_columns.include?(matcher)
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
      st_cols = cols.map(&:to_s)
      sy_cols = cols.map(&:to_sym)
      if including_columns_subclass_cache[sy_cols].present?
        return including_columns_subclass_cache[sy_cols]
      else
        subclass_name = including_ignored_columns_subclass_name(st_cols)
        begin
          including_columns_subclass_cache[sy_cols] = Object.const_get(subclass_name)
          return including_columns_subclass_cache[sy_cols]
        rescue NameError
          including_columns_subclass_cache[sy_cols] = generate_subclass_for_ignored_cols(subclass_name, st_cols)
        end
      end
    end

    def columns # :nodoc:
      return super unless ignorable_columns
      if @all_columns
        @columns ||= super.reject { |col| ignored_column?(col) }
      else
        @all_columns = super
        @columns = super.reject { |col| ignored_column?(col) }
      end
    end

    def column_names # :nodoc:
      return super unless ignorable_columns
      if @all_column_names
        @column_names ||= @all_column_names.reject { |col| ignored_column?(col) }
      else
        @all_column_names = all_columns.map(&:name)
        @column_names = @all_column_names.reject { |col| ignored_column?(col) }
      end
    end

    def attribute_types
      return super unless ignorable_columns
      @attribute_types = super.reject { |col| ignored_column?(col) }
    end

    def columns_hash
      return super unless ignorable_columns
      @columns_hash = super.reject { |col| ignored_column?(col) }
    end

    def include_columns? # :nodoc:
      @include_columns
    end

    def included_columns # :nodoc:
      @included_columns
    end

    def reset_ignorable_columns
      reset_columns
      self.default_scopes = orig_default_scopes
    end

    def including_ignored_columns_subclass_name(cols = nil)
      subclass_name = name + 'With'
      subclass_name += if cols.present?
                         cols.sort.map(&:camelcase).join
                       else
                         'All'
                       end
      subclass_name
    end

    def generate_subclass_for_ignored_cols(name, st_cols)
      new_subclass = Object.const_set(name, Class.new(self))
      temp_ignorable_columns = st_cols.present? ? ignorable_columns - st_cols : []

      new_subclass.reset_ignorable_columns
      new_subclass.ignorable_columns = temp_ignorable_columns
      new_subclass.default_scopes = orig_default_scopes
      new_subclass.ignore_columns_in_sql if default_scopes != orig_default_scopes

      new_subclass
    end

    def including_columns_subclass_cache
      @including_columns_subclass_cache ||= {}
    end

    def default_scopes_cache
      @default_scopes_cache ||= {}
    end

    def all_columns
      columns unless @all_columns
      @all_columns
    end

    def all_column_names
      column_names unless @all_column_names
      @all_column_names
    end

    def orig_default_scopes
      default_scopes - default_scopes_cache.values
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
  end

  def self.included(base)
    base.send :include, InstanceMethods
    base.extend ClassMethods
    base.send :class_attribute, :ignorable_columns
  end
end

ActiveRecord::Base.send(:include, IgnorableColumns) unless ActiveRecord::Base.include?(IgnorableColumns::InstanceMethods)
