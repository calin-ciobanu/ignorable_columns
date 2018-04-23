require 'spec_helper'
require 'byebug'

describe IgnorableColumns do
  class TestModel < ActiveRecord::Base
    unless table_exists?
      connection.create_table :test_models do |t|
        t.string :name
        t.string :some_attributes
        t.integer :legacy
      end
    end

    has_many :things
  end

  class Thing < ActiveRecord::Base
    unless table_exists?
      connection.create_table :things do |t|
        t.integer :test_model_id
        t.integer :value
        t.datetime :updated_at
        t.datetime :created_at
      end
    end

    belongs_to :test_model
  end

  class SubclassTestModel < TestModel
  end

  around :each do |example|
    ActiveRecord::Base.transaction do
      example.call
      raise ActiveRecord::Rollback
    end
  end

  let(:test_model) do
    Object.const_set("TestModel_#{(Time.now.to_f * 10**6).to_i}", Class.new(ActiveRecord::Base) do
      self.table_name = 'test_models'
    end)
  end
  let(:sub_test_model) do
    Object.const_set("SubTestModel_#{(Time.now.to_f * 10**6).to_i}", Class.new(test_model))
  end
  let(:thing) do
    Object.const_set("Thing_#{(Time.now.to_f * 10**6).to_i}", Class.new(ActiveRecord::Base) do
      self.table_name = 'things'
    end)
  end

  describe '#ignore_columns_in_sql' do
    context 'when without including_ignored_columns and without ignore_columns' do
      before do
        test_model.ignore_columns
        test_model.ignore_columns_in_sql
        TestModel.ignorable_columns = []
        TestModel.ignore_columns_in_sql
      end

      it 'should query all columns' do
        expect { test_model.all }.to include_col_in_sql(:test_models, :name)
        expect { test_model.all }.to include_col_in_sql(:test_models, :some_attributes)
        expect { test_model.all }.to include_col_in_sql(:test_models, :legacy)
        expect { TestModel.includes(:things) }.to include_col_in_sql(:test_models, :name)
        expect { TestModel.includes(:things) }.to include_col_in_sql(:test_models, :some_attributes)
        expect { TestModel.includes(:things) }.to include_col_in_sql(:test_models, :legacy)
        expect { TestModel.eager_load(:things) }.to include_col_in_sql(:test_models, :name)
        expect { TestModel.eager_load(:things) }.to include_col_in_sql(:test_models, :some_attributes)
        expect { TestModel.eager_load(:things) }.to include_col_in_sql(:test_models, :legacy)
      end
    end

    context 'when without including_ignored_columns and with ignore_columns' do
      before do
        test_model.ignore_columns :name, :some_attributes
        test_model.ignore_columns_in_sql
        TestModel.ignorable_columns = []
        TestModel.ignore_columns :name, :some_attributes
        TestModel.ignore_columns_in_sql
      end

      it 'should query all columns' do
        expect { test_model.all }.not_to include_col_in_sql(:test_models, :name)
        expect { test_model.all }.not_to include_col_in_sql(:test_models, :some_attributes)
        expect { test_model.all }.to include_col_in_sql(:test_models, :legacy)
        expect { TestModel.includes(:things) }.not_to include_col_in_sql(:test_models, :name)
        expect { TestModel.includes(:things) }.not_to include_col_in_sql(:test_models, :some_attributes)
        expect { TestModel.includes(:things) }.to include_col_in_sql(:test_models, :legacy)
        expect { TestModel.eager_load(:things) }.not_to include_col_in_sql(:test_models, :name)
        expect { TestModel.eager_load(:things) }.not_to include_col_in_sql(:test_models, :some_attributes)
        expect { TestModel.eager_load(:things) }.to include_col_in_sql(:test_models, :legacy)
      end
    end

    context 'when with all including_ignored_columns' do
      before do
        test_model.ignore_columns :name, :some_attributes
        test_model.ignore_columns_in_sql
      end

      it 'should query all columns' do
        expect { test_model.including_ignored_columns.all }.to include_col_in_sql(:test_models, :name)
        expect { test_model.including_ignored_columns.all }.to include_col_in_sql(:test_models, :some_attributes)
        expect { test_model.including_ignored_columns.all }.to include_col_in_sql(:test_models, :legacy)
      end
    end

    context 'when with some including_ignored_columns' do
      before do
        test_model.ignore_columns :name, :some_attributes
        test_model.ignore_columns_in_sql
      end

      it 'should query all columns' do
        expect { test_model.including_ignored_columns(:name).all }.to include_col_in_sql(:test_models, :name)
        expect { test_model.including_ignored_columns(:name).all }.not_to include_col_in_sql(:test_models, :some_attributes)
        expect { test_model.including_ignored_columns(:name).all }.to include_col_in_sql(:test_models, :legacy)
      end
    end
  end

  describe '#columns' do
    context 'when without including_ignored_columns' do
      context 'when ignore_columns is called before the columns are loaded' do
        before do
          test_model.ignore_columns :some_attributes, :name
          thing.ignore_columns :updated_at, :created_at
        end

        it 'should remove the columns from the class' do
          expect(test_model.columns.map(&:name)).to match_array %w[id legacy]
          expect(thing.columns.map(&:name)).to match_array %w[id test_model_id value]
        end

        it 'removes columns from the subclass' do
          expect(sub_test_model.columns.map(&:name)).to match_array(%w[id legacy])
        end
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          test_model.columns
          sub_test_model.columns
          test_model.ignore_columns :some_attributes, :legacy
        end

        it 'removes columns from the class' do
          expect(test_model.columns.map(&:name)).to match_array(%w[id name])
        end

        it 'removes columns from the subclass' do
          expect(sub_test_model.columns.map(&:name)).to match_array(%w[id name])
        end
      end
    end

    context 'when with all including_ignored_columns' do
      before do
        test_model.ignore_columns :some_attributes, :legacy
      end

      context 'when ignore_columns is called before the columns are loaded' do
        it 'should readds the columns from the class' do
          expect(
            test_model.including_ignored_columns.columns.map(&:name)
          ).to match_array %w[id legacy some_attributes name]
          expect(
            thing.including_ignored_columns.columns.map(&:name)
          ).to match_array %w[id test_model_id value updated_at created_at]
        end

        it 'readds columns from the subclass' do
          expect(
            sub_test_model.including_ignored_columns.columns.map(&:name)
          ).to match_array(%w[id legacy some_attributes name])
        end
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          test_model.columns
          sub_test_model.columns
          test_model.ignore_columns :some_attributes, :legacy
        end

        it 'readds columns from the class' do
          expect(
            test_model.including_ignored_columns.columns.map(&:name)
          ).to match_array(%w[id legacy some_attributes name])
        end

        it 'readds columns from the subclass' do
          expect(
            sub_test_model.including_ignored_columns.columns.map(&:name)
          ).to match_array(%w[id legacy some_attributes name])
        end
      end
    end

    context 'when with some including_ignored_columns' do
      before do
        test_model.columns
        sub_test_model.columns
        test_model.ignore_columns :some_attributes, :legacy
        thing.ignore_columns :created_at, :updated_at
      end

      context 'when ignore_columns is called before the columns are loaded' do
        it 'should remove the columns from the class' do
          expect(
            test_model.including_ignored_columns(:some_attributes).columns.map(&:name)
          ).to match_array %w[id some_attributes name]
          expect(
            thing.including_ignored_columns(:created_at).columns.map(&:name)
          ).to match_array %w[id test_model_id value created_at]
        end

        it 'removes columns from the subclass' do
          expect(
            sub_test_model.including_ignored_columns(:some_attributes).columns.map(&:name)
          ).to match_array(%w[id some_attributes name])
        end
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          test_model.columns
          sub_test_model.columns
          test_model.ignore_columns :some_attributes, :legacy
        end

        it 'removes columns from the class' do
          expect(
            test_model.including_ignored_columns(:some_attributes).columns.map(&:name)
          ).to match_array(%w[id some_attributes name])
        end

        it 'removes columns from the subclass' do
          expect(
            sub_test_model.including_ignored_columns(:some_attributes).columns.map(&:name)
          ).to match_array(%w[id some_attributes name])
        end
      end
    end
  end

  describe '#column_names' do
    context 'when without including_ignored_columns' do
      context 'when ignore_columns is called before the columns are loaded' do
        before do
          test_model.ignore_columns :some_attributes, :legacy
          thing.ignore_column :updated_at, :created_at
        end

        it 'should remove the columns from the class' do
          expect(test_model.column_names).to match_array %w[id name]
          expect(thing.column_names).to match_array %w[id test_model_id value]
        end

        it 'removes columns from the subclass' do
          expect(sub_test_model.column_names).to match_array(%w[id name])
        end
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          test_model.columns
          sub_test_model.columns
          test_model.ignore_columns :some_attributes, :legacy
        end

        it 'removes columns from the class' do
          expect(test_model.column_names).to match_array(%w[id name])
        end

        it 'removes columns from the subclass' do
          expect(sub_test_model.column_names).to match_array(%w[id name])
        end
      end
    end

    context 'when with all including_ignored_columns' do
      before do
        test_model.ignore_columns :some_attributes, :legacy
        thing.ignore_column :updated_at, :created_at
      end

      context 'when ignore_columns is called before the columns are loaded' do
        it 'should readds the columns from the class' do
          expect(
            test_model.including_ignored_columns.column_names
          ).to match_array %w[id legacy some_attributes name]
          expect(
            thing.including_ignored_columns.column_names
          ).to match_array %w[id test_model_id value updated_at created_at]
        end

        it 'readds columns from the subclass' do
          expect(
            sub_test_model.including_ignored_columns.column_names
          ).to match_array(%w[id legacy some_attributes name])
        end
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          test_model.columns
          sub_test_model.columns
          test_model.ignore_columns :some_attributes, :legacy
        end

        it 'readds columns from the class' do
          expect(
            test_model.including_ignored_columns.column_names
          ).to match_array(%w[id legacy some_attributes name])
        end

        it 'readds columns from the subclass' do
          expect(
            sub_test_model.including_ignored_columns.column_names
          ).to match_array(%w[id legacy some_attributes name])
        end
      end
    end

    context 'when with some including_ignored_columns' do
      context 'when ignore_columns is called before the columns are loaded' do
        before do
          test_model.ignore_columns :some_attributes, :legacy
          thing.ignore_column :updated_at, :created_at
        end

        it 'should remove the columns from the class' do
          expect(
            test_model.including_ignored_columns(:some_attributes).column_names
          ).to match_array %w[id some_attributes name]
          expect(
            thing.including_ignored_columns(:created_at).column_names
          ).to match_array %w[id test_model_id value created_at]
        end

        it 'removes columns from the subclass' do
          expect(
            sub_test_model.including_ignored_columns(:some_attributes).column_names
          ).to match_array(%w[id some_attributes name])
        end
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          test_model.columns
          sub_test_model.columns
          test_model.ignore_columns :some_attributes, :legacy
        end

        it 'removes columns from the class' do
          expect(
            test_model.including_ignored_columns(:some_attributes).column_names
          ).to match_array(%w[id some_attributes name])
        end

        it 'removes columns from the subclass' do
          expect(
            sub_test_model.including_ignored_columns(:some_attributes).column_names
          ).to match_array(%w[id some_attributes name])
        end
      end
    end
  end

  describe '#attributes' do
    before do
      test_model.ignore_columns :some_attributes, :legacy
      TestModel.ignorable_columns = []
      TestModel.ignore_columns :some_attributes, :legacy
      thing.ignore_column :updated_at, :created_at
      Thing.ignorable_columns = []
      Thing.ignore_column :updated_at, :created_at
    end

    context 'when without including_ignored_columns' do
      it 'should remove the columns from the attributes hash' do
        expect(test_model.new.attributes.keys).to match_array %w[id name]
        expect(thing.new.attributes.keys).to match_array %w[id test_model_id value]
      end

      it 'should remove the accessor methods' do
        expect(thing.new).to_not respond_to(:updated_at)
        expect(thing.new).to_not respond_to(:updated_at=)
      end

      it 'should not override existing methods with ignored column accessors' do
        model = test_model.new
        expect(model.attributes).to eql('id' => nil, 'name' => nil)
        model.attributes = { name: 'test' }
        expect(model.name).to eql 'test'
      end

      it 'should not affect inserts' do
        model = test_model.create!(name: 'test')
        model.reload
        expect(model.name).to eql 'test'
        expect(model.attributes['legacy']).to be_nil
      end

      it 'should not affect selects' do
        test_model.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
        model = test_model.where(name: 'test').first
        expect(model.name).to eql 'test'
        expect(model.attributes['legacy']).to eql nil
        expect(model.attributes['some_attributes']).to eql nil
      end

      it 'should not affect updates' do
        test_model.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
        model = test_model.where(name: 'test').first
        model.name = 'test2'
        model.save!
        results = test_model.connection.select_one("SELECT name, legacy, some_attributes from test_models where name = 'test2'")
        expect(results).to eql('name' => 'test2', 'legacy' => 1, 'some_attributes' => 'woo')
      end

      it 'should work with associations' do
        TestModel.connection.insert("INSERT INTO test_models (id, name, legacy, some_attributes) VALUES (1, 'test', 1, 'woo')")
        Thing.connection.insert("INSERT INTO things (id, test_model_id, value, updated_at, created_at) VALUES (1, 1, 10, '#{Time.now.to_formatted_s(:db)}', '#{Time.now.to_formatted_s(:db)}')")
        model = TestModel.create!(name: 'test')
        thingy = Thing.create!(test_model_id: model.id, value: 10)
        expect(model.things.first.value).to eql 10
        expect(thingy.test_model.name).to eql 'test'
      end

      it 'should work with magic timestamp columns' do
        thingy = Thing.create!(test_model_id: 1, value: 10)
        results = Thing.connection.select_one("SELECT id, value, test_model_id, updated_at, created_at FROM things where id = #{thingy.id}")
        expect(results).to eql('id' => 1, 'value' => 10, 'test_model_id' => 1, 'updated_at' => nil, 'created_at' => nil)
      end
    end

    context 'when with all including_ignored_columns' do
      it 'should readd the columns from the attributes hash' do
        expect(
          test_model.including_ignored_columns.new.attributes.keys
        ).to match_array %w[id name legacy some_attributes]
        expect(
          thing.including_ignored_columns.new.attributes.keys
        ).to match_array %w[id test_model_id value updated_at created_at]
      end

      it 'should readd the accessor methods' do
        thing.including_ignored_columns do
          expect(thing.new).to respond_to(:updated_at)
          expect(thing.new).to respond_to(:created_at)
          expect(thing.new).to respond_to(:updated_at=)
          expect(thing.new).to respond_to(:created_at=)
        end
      end

      it 'should not override existing methods with ignored column accessors' do
        test_model.including_ignored_columns do
          model = test_model.new
          expect(model.attributes).to eql('id' => nil, 'name' => nil, 'legacy' => nil, 'some_attributes' => nil)
          model.attributes = { name: 'test' }
          expect(model.name).to eql 'test'
        end
      end

      it 'should not affect inserts' do
        test_model.including_ignored_columns do
          model = test_model.create!(name: 'test', legacy: 2)
          model.reload
          expect(model.name).to eql 'test'
          expect(model.attributes['legacy']).to eq 2
        end
      end

      it 'should not affect selects' do
        test_model.including_ignored_columns do
          test_model.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
          model = test_model.where(name: 'test').first
          expect(model.name).to eql 'test'
          expect(model.attributes['legacy']).to eql 1
          expect(model.attributes['some_attributes']).to eql 'woo'
        end
      end

      it 'should not affect updates' do
        test_model.including_ignored_columns do
          test_model.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
          model = test_model.where(name: 'test').first
          model.name = 'test2'
          model.save!
          results = test_model.connection.select_one("SELECT name, legacy, some_attributes from test_models where name = 'test2'")
          expect(results).to eql('name' => 'test2', 'legacy' => 1, 'some_attributes' => 'woo')
        end
      end

      it 'should work with associations' do
        test_model.including_ignored_columns do
          thing.including_ignored_columns do
            TestModel.connection.insert("INSERT INTO test_models (id, name, legacy, some_attributes) VALUES (1, 'test', 1, 'woo')")
            Thing.connection.insert("INSERT INTO things (id, test_model_id, value, updated_at, created_at) VALUES (1, 1, 10, '#{Time.now.to_formatted_s(:db)}', '#{Time.now.to_formatted_s(:db)}')")
            model = TestModel.create!(name: 'test')
            thingy = Thing.create!(test_model_id: model.id, value: 10)
            expect(model.things.first.value).to eql 10
            expect(thingy.test_model.name).to eql 'test'
          end
        end
      end

      it 'should work with magic timestamp columns' do
        thing.including_ignored_columns do
          thingy = thing.create!(test_model_id: 1, value: 10)
          results = thing.connection.select_one("SELECT id, value, test_model_id, updated_at, created_at FROM things where id = #{thingy.id}")
          expect(results).to eq('id' => 1, 'value' => 10, 'test_model_id' => 1, 'updated_at' => results['updated_at'], 'created_at' => results['created_at'])
        end
      end
    end

    context 'when with some including_ignored_columns' do
      it 'should readd the columns from the attributes hash' do
        expect(
          test_model.including_ignored_columns(:legacy).new.attributes.keys
        ).to match_array %w[id name legacy]
        expect(
          thing.including_ignored_columns(:updated_at).new.attributes.keys
        ).to match_array %w[id test_model_id value updated_at]
      end

      it 'should readd the accessor methods' do
        thing.including_ignored_columns(:updated_at) do
          expect(thing.new).to respond_to(:updated_at)
          expect(thing.new).not_to respond_to(:created_at)
          expect(thing.new).to respond_to(:updated_at=)
          expect(thing.new).not_to respond_to(:created_at=)
        end
      end

      it 'should not override existing methods with ignored column accessors' do
        test_model.including_ignored_columns(:legacy) do
          model = test_model.new
          expect(model.attributes).to eql('id' => nil, 'name' => nil, 'legacy' => nil)
          model.attributes = { name: 'test' }
          expect(model.name).to eql 'test'
        end
      end

      it 'should not affect inserts' do
        test_model.including_ignored_columns(:legacy) do
          model = test_model.create!(name: 'test', legacy: 2)
          model.reload
          expect(model.name).to eql 'test'
          expect(model.attributes['legacy']).to eq 2
        end
      end

      it 'should not affect selects' do
        test_model.including_ignored_columns(:legacy) do
          test_model.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
          model = test_model.where(name: 'test').first
          expect(model.name).to eql 'test'
          expect(model.attributes['legacy']).to eql 1
          expect(model.attributes['some_attributes']).to eq nil
        end
      end

      it 'should not affect updates' do
        test_model.including_ignored_columns(:legacy) do
          test_model.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
          model = test_model.where(name: 'test').first
          model.name = 'test2'
          model.save!
          results = test_model.connection.select_one("SELECT name, legacy, some_attributes from test_models where name = 'test2'")
          expect(results).to eql('name' => 'test2', 'legacy' => 1, 'some_attributes' => 'woo')
        end
      end

      it 'should work with associations' do
        test_model.including_ignored_columns(:legacy) do
          thing.including_ignored_columns(:updated_at) do
            TestModel.connection.insert("INSERT INTO test_models (id, name, legacy, some_attributes) VALUES (1, 'test', 1, 'woo')")
            Thing.connection.insert("INSERT INTO things (id, test_model_id, value, updated_at, created_at) VALUES (1, 1, 10, '#{Time.now.to_formatted_s(:db)}', '#{Time.now.to_formatted_s(:db)}')")
            model = TestModel.create!(name: 'test')
            thingy = Thing.create!(test_model_id: model.id, value: 10)
            expect(model.things.first.value).to eql 10
            expect(thingy.test_model.name).to eql 'test'
          end
        end
      end

      it 'should work with magic timestamp columns' do
        thing.including_ignored_columns(:updated_at) do
          thingy = thing.create!(test_model_id: 1, value: 10)
          results = thing.connection.select_one("SELECT id, value, test_model_id, updated_at, created_at FROM things where id = #{thingy.id}")
          expect(results).to eql('id' => 1, 'value' => 10, 'test_model_id' => 1, 'updated_at' => results['updated_at'], 'created_at' => nil)
        end
      end
    end
  end

  describe '#attribute_names' do
    before do
      test_model.ignore_columns :some_attributes, :legacy
      thing.ignore_column :updated_at, :created_at
    end

    context 'when without including_ignored_columns' do
      it 'should remove the columns from the attribute names' do
        expect(test_model.new.attribute_names).to match_array %w[id name]
        expect(thing.new.attribute_names).to match_array %w[id test_model_id value]
      end
    end

    context 'when with all including_ignored_columns' do
      it 'should remove the columns from the attribute names' do
        test_model.including_ignored_columns do
          expect(test_model.new.attribute_names).to match_array %w[id name legacy some_attributes]
        end

        thing.including_ignored_columns do
          expect(thing.new.attribute_names).to match_array %w[id test_model_id value updated_at created_at]
        end
      end
    end

    context 'when with some including_ignored_columns' do
      it 'should remove the columns from the attribute names' do
        test_model.including_ignored_columns(:legacy) do
          expect(test_model.new.attribute_names).to match_array %w[id name legacy]
        end

        thing.including_ignored_columns(:updated_at) do
          expect(thing.new.attribute_names).to match_array %w[id test_model_id value updated_at]
        end
      end
    end
  end
end
