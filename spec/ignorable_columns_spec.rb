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

    ignore_columns :legacy, :some_attributes
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

    ignore_column :updated_at, :created_at
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

  describe '#ignore_columns_in_sql' do
    before do
      @test_model = Class.new(ActiveRecord::Base) do
        self.table_name = 'test_models'
      end
      @subclass = Class.new(@test_model)

      # @test_model.ignore_columns :some_attributes, :legacy
    end

    context 'when without with_ignored_columns' do
      before { @test_model.ignore_columns_in_sql }

      it 'should query all columns' do
        expect { @test_model.all }.to include_col_in_sql(:test_models, :name)
        expect { @test_model.all }.to include_col_in_sql(:test_models, :some_attributes)
        expect { @test_model.all }.to include_col_in_sql(:test_models, :legacy)
      end
    end

    context 'when without with_ignored_columns' do
      before do
        @test_model.ignore_columns :name, :some_attributes
        @test_model.ignore_columns_in_sql
      end

      it 'should query all columns' do
        expect { @test_model.all }.not_to include_col_in_sql(:test_models, :name)
        expect { @test_model.all }.not_to include_col_in_sql(:test_models, :some_attributes)
        expect { @test_model.all }.to include_col_in_sql(:test_models, :legacy)
      end
    end

    context 'when with all with_ignored_columns' do
      before do
        @test_model.ignore_columns :name, :some_attributes
        @test_model.ignore_columns_in_sql
      end

      it 'should query all columns' do
        @test_model.with_ignored_columns do
          expect { @test_model.all }.to include_col_in_sql(:test_models, :name)
          expect { @test_model.all }.to include_col_in_sql(:test_models, :some_attributes)
          expect { @test_model.all }.to include_col_in_sql(:test_models, :legacy)
        end
      end
    end

    context 'when with some with_ignored_columns' do
      before do
        @test_model.ignore_columns :name, :some_attributes
        @test_model.ignore_columns_in_sql
      end

      it 'should query all columns' do
        @test_model.with_ignored_columns(:name) do
          expect { @test_model.all }.to include_col_in_sql(:test_models, :name)
          expect { @test_model.all }.not_to include_col_in_sql(:test_models, :some_attributes)
          expect { @test_model.all }.to include_col_in_sql(:test_models, :legacy)
        end
      end
    end
  end

  describe '#columns' do
    context 'when without with_ignored_columns' do
      it 'should remove the columns from the class' do
        expect(TestModel.columns.map(&:name)).to match_array %w[id name]
        expect(Thing.columns.map(&:name)).to match_array %w[id test_model_id value]
      end

      it 'removes columns from the subclass' do
        expect(SubclassTestModel.columns.map(&:name)).to match_array(%w[id name])
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          @test_model = Class.new(ActiveRecord::Base) do
            self.table_name = 'test_models'
          end
          @subclass = Class.new(@test_model)

          # Force columns to load
          @test_model.columns
          @subclass.columns

          @test_model.ignore_columns :some_attributes, :legacy
        end

        it 'removes columns from the class' do
          expect(@test_model.columns.map(&:name)).to match_array(%w[id name])
        end

        it 'removes columns from the subclass' do
          expect(@subclass.columns.map(&:name)).to match_array(%w[id name])
        end
      end
    end

    context 'when with all with_ignored_columns' do
      it 'should readds the columns from the class' do
        expect(
          TestModel.with_ignored_columns do
            TestModel.columns.map(&:name)
          end
        ).to match_array %w[id legacy some_attributes name]
        expect(
          Thing.with_ignored_columns do
            Thing.columns.map(&:name)
          end
        ).to match_array %w[id test_model_id value updated_at created_at]
      end

      it 'readds columns from the subclass' do
        expect(
          SubclassTestModel.with_ignored_columns do
            SubclassTestModel.columns.map(&:name)
          end
        ).to match_array(%w[id legacy some_attributes name])
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          @test_model = Class.new(ActiveRecord::Base) do
            self.table_name = 'test_models'
          end
          @subclass = Class.new(@test_model)
          @test_model.columns
          @subclass.columns
          @test_model.ignore_columns :some_attributes, :legacy
        end

        it 'readds columns from the class' do
          expect(
            @test_model.with_ignored_columns do
              @test_model.columns.map(&:name)
            end
          ).to match_array(%w[id legacy some_attributes name])
        end

        it 'readds columns from the subclass' do
          expect(
            @subclass.with_ignored_columns do
              @subclass.columns.map(&:name)
            end
          ).to match_array(%w[id legacy some_attributes name])
        end
      end
    end

    context 'when with some with_ignored_columns' do
      it 'should remove the columns from the class' do
        expect(
          TestModel.with_ignored_columns(:some_attributes) do
            TestModel.columns.map(&:name)
          end
        ).to match_array %w[id some_attributes name]
        expect(
          Thing.with_ignored_columns(:created_at) do
            Thing.columns.map(&:name)
          end
        ).to match_array %w[id test_model_id value created_at]
      end

      it 'removes columns from the subclass' do
        expect(
          SubclassTestModel.with_ignored_columns(:some_attributes) do
            SubclassTestModel.columns.map(&:name)
          end
        ).to match_array(%w[id some_attributes name])
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          @test_model = Class.new(ActiveRecord::Base) do
            self.table_name = 'test_models'
          end
          @subclass = Class.new(@test_model)
          @test_model.columns
          @subclass.columns
          @test_model.ignore_columns :some_attributes, :legacy
        end

        it 'removes columns from the class' do
          expect(
            @test_model.with_ignored_columns(:some_attributes) do
              @test_model.columns.map(&:name)
            end
          ).to match_array(%w[id some_attributes name])
        end

        it 'removes columns from the subclass' do
          expect(
            @subclass.with_ignored_columns(:some_attributes) do
              @subclass.columns.map(&:name)
            end
          ).to match_array(%w[id some_attributes name])
        end
      end
    end
  end

  describe '#column_names' do
    context 'when without with_ignored_columns' do
      it 'should remove the columns from the class' do
        expect(TestModel.column_names).to match_array %w[id name]
        expect(Thing.column_names).to match_array %w[id test_model_id value]
      end

      it 'removes columns from the subclass' do
        expect(SubclassTestModel.column_names).to match_array(%w[id name])
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          @test_model = Class.new(ActiveRecord::Base) do
            self.table_name = 'test_models'
          end
          @subclass = Class.new(@test_model)
          @test_model.columns
          @subclass.columns
          @test_model.ignore_columns :some_attributes, :legacy
        end

        it 'removes columns from the class' do
          expect(@test_model.column_names).to match_array(%w[id name])
        end

        it 'removes columns from the subclass' do
          expect(@subclass.column_names).to match_array(%w[id name])
        end
      end
    end

    context 'when with all with_ignored_columns' do
      it 'should readds the columns from the class' do
        expect(
          TestModel.with_ignored_columns do
            TestModel.column_names
          end
        ).to match_array %w[id legacy some_attributes name]
        expect(
          Thing.with_ignored_columns do
            Thing.column_names
          end
        ).to match_array %w[id test_model_id value updated_at created_at]
      end

      it 'readds columns from the subclass' do
        expect(
          SubclassTestModel.with_ignored_columns do
            SubclassTestModel.column_names
          end
        ).to match_array(%w[id legacy some_attributes name])
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          @test_model = Class.new(ActiveRecord::Base) do
            self.table_name = 'test_models'
          end
          @subclass = Class.new(@test_model)
          @test_model.columns
          @subclass.columns
          @test_model.ignore_columns :some_attributes, :legacy
        end

        it 'readds columns from the class' do
          expect(
            @test_model.with_ignored_columns do
              @test_model.column_names
            end
          ).to match_array(%w[id legacy some_attributes name])
        end

        it 'readds columns from the subclass' do
          expect(
            @subclass.with_ignored_columns do
              @subclass.column_names
            end
          ).to match_array(%w[id legacy some_attributes name])
        end
      end
    end

    context 'when with some with_ignored_columns' do
      it 'should remove the columns from the class' do
        expect(
          TestModel.with_ignored_columns(:some_attributes) do
            TestModel.column_names
          end
        ).to match_array %w[id some_attributes name]
        expect(
          Thing.with_ignored_columns(:created_at) do
            Thing.column_names
          end
        ).to match_array %w[id test_model_id value created_at]
      end

      it 'removes columns from the subclass' do
        expect(
          SubclassTestModel.with_ignored_columns(:some_attributes) do
            SubclassTestModel.column_names
          end
        ).to match_array(%w[id some_attributes name])
      end

      context 'when ignore_columns is called after the columns are loaded' do
        before do
          @test_model = Class.new(ActiveRecord::Base) do
            self.table_name = 'test_models'
          end
          @subclass = Class.new(@test_model)
          @test_model.columns
          @subclass.columns
          @test_model.ignore_columns :some_attributes, :legacy
        end

        it 'removes columns from the class' do
          expect(
            @test_model.with_ignored_columns(:some_attributes) do
              @test_model.column_names
            end
          ).to match_array(%w[id some_attributes name])
        end

        it 'removes columns from the subclass' do
          expect(
            @subclass.with_ignored_columns(:some_attributes) do
              @subclass.column_names
            end
          ).to match_array(%w[id some_attributes name])
        end
      end
    end
  end

  describe '#attributes' do
    context 'when without with_ignored_columns' do
      it 'should remove the columns from the attributes hash' do
        expect(TestModel.new.attributes.keys).to match_array %w[id name]
        expect(Thing.new.attributes.keys).to match_array %w[id test_model_id value]
      end

      it 'should remove the accessor methods' do
        expect(Thing.new).to_not respond_to(:updated_at)
        expect(Thing.new).to_not respond_to(:updated_at=)
      end

      it 'should not override existing methods with ignored column accessors' do
        model = TestModel.new
        expect(model.attributes).to eql('id' => nil, 'name' => nil)
        model.attributes = { name: 'test' }
        expect(model.name).to eql 'test'
      end

      it 'should not affect inserts' do
        model = TestModel.create!(name: 'test')
        model.reload
        expect(model.name).to eql 'test'
        expect(model.attributes['legacy']).to be_nil
      end

      it 'should not affect selects' do
        TestModel.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
        model = TestModel.where(name: 'test').first
        expect(model.name).to eql 'test'
        expect(model.attributes['legacy']).to eql nil
        expect(model.attributes['some_attributes']).to eql nil
      end

      it 'should not affect updates' do
        TestModel.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
        model = TestModel.where(name: 'test').first
        model.name = 'test2'
        model.save!
        results = TestModel.connection.select_one("SELECT name, legacy, some_attributes from test_models where name = 'test2'")
        expect(results).to eql('name' => 'test2', 'legacy' => 1, 'some_attributes' => 'woo')
      end

      it 'should work with associations' do
        TestModel.connection.insert("INSERT INTO test_models (id, name, legacy, some_attributes) VALUES (1, 'test', 1, 'woo')")
        Thing.connection.insert("INSERT INTO things (id, test_model_id, value, updated_at, created_at) VALUES (1, 1, 10, '#{Time.now.to_formatted_s(:db)}', '#{Time.now.to_formatted_s(:db)}')")
        model = TestModel.create!(name: 'test')
        thing = Thing.create!(test_model_id: model.id, value: 10)
        expect(model.things.first.value).to eql 10
        expect(thing.test_model.name).to eql 'test'
      end

      it 'should work with magic timestamp columns' do
        thing = Thing.create!(test_model_id: 1, value: 10)
        results = Thing.connection.select_one("SELECT id, value, test_model_id, updated_at, created_at FROM things where id = #{thing.id}")
        expect(results).to eql('id' => 1, 'value' => 10, 'test_model_id' => 1, 'updated_at' => nil, 'created_at' => nil)
      end
    end

    context 'when with all with_ignored_columns' do
      it 'should readd the columns from the attributes hash' do
        expect(
          TestModel.with_ignored_columns do
            TestModel.new.attributes.keys
          end
        ).to match_array %w[id name legacy some_attributes]
        expect(
          Thing.with_ignored_columns do
            Thing.new.attributes.keys
          end
        ).to match_array %w[id test_model_id value updated_at created_at]
      end

      it 'should readd the accessor methods' do
        Thing.with_ignored_columns do
          expect(Thing.new).to respond_to(:updated_at)
          expect(Thing.new).to respond_to(:created_at)
          expect(Thing.new).to respond_to(:updated_at=)
          expect(Thing.new).to respond_to(:created_at=)
        end
      end

      it 'should not override existing methods with ignored column accessors' do
        TestModel.with_ignored_columns do
          model = TestModel.new
          expect(model.attributes).to eql('id' => nil, 'name' => nil, 'legacy' => nil, 'some_attributes' => nil)
          model.attributes = { name: 'test' }
          expect(model.name).to eql 'test'
        end
      end

      it 'should not affect inserts' do
        TestModel.with_ignored_columns do
          model = TestModel.create!(name: 'test', legacy: 2)
          model.reload
          expect(model.name).to eql 'test'
          expect(model.attributes['legacy']).to eq 2
        end
      end

      it 'should not affect selects' do
        TestModel.with_ignored_columns do
          TestModel.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
          model = TestModel.where(name: 'test').first
          expect(model.name).to eql 'test'
          expect(model.attributes['legacy']).to eql 1
          expect(model.attributes['some_attributes']).to eql 'woo'
        end
      end

      it 'should not affect updates' do
        TestModel.with_ignored_columns do
          TestModel.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
          model = TestModel.where(name: 'test').first
          model.name = 'test2'
          model.save!
          results = TestModel.connection.select_one("SELECT name, legacy, some_attributes from test_models where name = 'test2'")
          expect(results).to eql('name' => 'test2', 'legacy' => 1, 'some_attributes' => 'woo')
        end
      end

      it 'should work with associations' do
        TestModel.with_ignored_columns do
          Thing.with_ignored_columns do
            TestModel.connection.insert("INSERT INTO test_models (id, name, legacy, some_attributes) VALUES (1, 'test', 1, 'woo')")
            Thing.connection.insert("INSERT INTO things (id, test_model_id, value, updated_at, created_at) VALUES (1, 1, 10, '#{Time.now.to_formatted_s(:db)}', '#{Time.now.to_formatted_s(:db)}')")
            model = TestModel.create!(name: 'test')
            thing = Thing.create!(test_model_id: model.id, value: 10)
            expect(model.things.first.value).to eql 10
            expect(thing.test_model.name).to eql 'test'
          end
        end
      end

      it 'should work with magic timestamp columns' do
        Thing.with_ignored_columns do
          thing = Thing.create!(test_model_id: 1, value: 10)
          results = Thing.connection.select_one("SELECT id, value, test_model_id, updated_at, created_at FROM things where id = #{thing.id}")
          expect(results).to eq('id' => 1, 'value' => 10, 'test_model_id' => 1, 'updated_at' => results['updated_at'], 'created_at' => results['created_at'])
        end
      end
    end

    context 'when with some with_ignored_columns' do
      it 'should readd the columns from the attributes hash' do
        expect(
          TestModel.with_ignored_columns(:legacy) do
            TestModel.new.attributes.keys
          end
        ).to match_array %w[id name legacy]
        expect(
          Thing.with_ignored_columns(:updated_at) do
            Thing.new.attributes.keys
          end
        ).to match_array %w[id test_model_id value updated_at]
      end

      it 'should readd the accessor methods' do
        Thing.with_ignored_columns(:updated_at) do
          expect(Thing.new).to respond_to(:updated_at)
          expect(Thing.new).not_to respond_to(:created_at)
          expect(Thing.new).to respond_to(:updated_at=)
          expect(Thing.new).not_to respond_to(:created_at=)
        end
      end

      it 'should not override existing methods with ignored column accessors' do
        TestModel.with_ignored_columns(:legacy) do
          model = TestModel.new
          expect(model.attributes).to eql('id' => nil, 'name' => nil, 'legacy' => nil)
          model.attributes = { name: 'test' }
          expect(model.name).to eql 'test'
        end
      end

      it 'should not affect inserts' do
        TestModel.with_ignored_columns(:legacy) do
          model = TestModel.create!(name: 'test', legacy: 2)
          model.reload
          expect(model.name).to eql 'test'
          expect(model.attributes['legacy']).to eq 2
        end
      end

      it 'should not affect selects' do
        TestModel.with_ignored_columns(:legacy) do
          TestModel.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
          model = TestModel.where(name: 'test').first
          expect(model.name).to eql 'test'
          expect(model.attributes['legacy']).to eql 1
          expect(model.attributes['some_attributes']).to eq nil
        end
      end

      it 'should not affect updates' do
        TestModel.with_ignored_columns(:legacy) do
          TestModel.connection.insert("INSERT INTO test_models (name, legacy, some_attributes) VALUES ('test', 1, 'woo')")
          model = TestModel.where(name: 'test').first
          model.name = 'test2'
          model.save!
          results = TestModel.connection.select_one("SELECT name, legacy, some_attributes from test_models where name = 'test2'")
          expect(results).to eql('name' => 'test2', 'legacy' => 1, 'some_attributes' => 'woo')
        end
      end

      it 'should work with associations' do
        TestModel.with_ignored_columns(:legacy) do
          Thing.with_ignored_columns(:updated_at) do
            TestModel.connection.insert("INSERT INTO test_models (id, name, legacy, some_attributes) VALUES (1, 'test', 1, 'woo')")
            Thing.connection.insert("INSERT INTO things (id, test_model_id, value, updated_at, created_at) VALUES (1, 1, 10, '#{Time.now.to_formatted_s(:db)}', '#{Time.now.to_formatted_s(:db)}')")
            model = TestModel.create!(name: 'test')
            thing = Thing.create!(test_model_id: model.id, value: 10)
            expect(model.things.first.value).to eql 10
            expect(thing.test_model.name).to eql 'test'
          end
        end
      end

      it 'should work with magic timestamp columns' do
        Thing.with_ignored_columns(:updated_at) do
          thing = Thing.create!(test_model_id: 1, value: 10)
          results = Thing.connection.select_one("SELECT id, value, test_model_id, updated_at, created_at FROM things where id = #{thing.id}")
          expect(results).to eql('id' => 1, 'value' => 10, 'test_model_id' => 1, 'updated_at' => results['updated_at'], 'created_at' => nil)
        end
      end
    end
  end

  describe '#attribute_names' do
    context 'when without with_ignored_columns' do
      it 'should remove the columns from the attribute names' do
        expect(TestModel.new.attribute_names).to match_array %w[id name]
        expect(Thing.new.attribute_names).to match_array %w[id test_model_id value]
      end
    end

    context 'when with all with_ignored_columns' do
      it 'should remove the columns from the attribute names' do
        TestModel.with_ignored_columns do
          expect(TestModel.new.attribute_names).to match_array %w[id name legacy some_attributes]
        end

        Thing.with_ignored_columns do
          expect(Thing.new.attribute_names).to match_array %w[id test_model_id value updated_at created_at]
        end
      end
    end

    context 'when with some with_ignored_columns' do
      it 'should remove the columns from the attribute names' do
        TestModel.with_ignored_columns(:legacy) do
          expect(TestModel.new.attribute_names).to match_array %w[id name legacy]
        end

        Thing.with_ignored_columns(:updated_at) do
          expect(Thing.new.attribute_names).to match_array %w[id test_model_id value updated_at]
        end
      end
    end
  end
end
