require 'spec_helper'
# This is a WIP and still unstructured. But I plan to use it in one of my apps. 

describe ::Session::Session do
  # This is a mock using the intermediate format interface 
  # of my mapper experiments http://github.com/mbj/mapper
  # Currently not compatible since expanded for keys!
  #
  # keys:
  #
  #   A key is any hash that identifies the database record/document/row
  #   where the operation should be performed. The key is created by mapping.
  class DummyMapper

    # Dumps an object into intermediate representation.
    # Two level hash, first level is collection, second the 
    # values for the entry.
    # So you can map to multiple collection entries.
    # Currently im only specing AR pattern in this test, 
    # but time will change!
    #
    def dump(object)
      { :domain_objects => dump_value(object) }
    end

    # Used internally
    def dump_value(object)
      {
        :key_attribute => object.key_attribute,
        :other_attribute => object.other_attribute
      }
    end

    # Loads an object from intermediate represenation.
    # Same format as dump but operation is reversed.
    # Construction of objects can be don in a ORM-Model component
    # specific subclass (Virtus?)
    #
    def load(model,dump)
      raise unless model == DomainObject
      values = dump.fetch(:domain_objects)

      DomainObject.new(
        values.fetch(:key_attribute),
        values.fetch(:other_attribute)
      )
    end

    # Dumps a key intermediate representation from object
    def dump_key(object)
      {
        :domain_objects => {
          :key_attribute => object.key_attribute
        }
      }
    end

    # Loads a key intermediate representation from dump
    def load_key(model,dump)
      raise unless model == DomainObject
      values = dump.fetch(:domain_objects)
      {
        :domain_objects => {
          :key_attribute => values.fetch(:key_attribute)
        }
      }
    end
  end

  # Dummy adapter that records interactions. 
  # The idea is to support the most basic crud operations.
  class DummyAdapter
    attr_reader :inserts,:deletes,:updates

    def initialize
      @deletes,@inserts,@updates = [],[],[]
    end

    # TODO: Some way to return generated keys?
    # @param [Symbol] collectio the collection where the record should be inserted
    # @param [Hash] the record to be inserted
    #
    def insert(collection,dump)
      @inserts << [collection,dump]
    end

    # @param [Symbol] collection the collection where the delete should happen
    # @param [Hash] delete_key the key identifying the record to delete
    #
    def delete(collection,delete_key)
      @deletes << [collection,delete_key]
    end

    # TODO: 4 params? Am I dump?
    # I need the old and the new record representation to generate some 
    # advanced mongo udpates.
    #
    # @param [Symbol] collection the collection where the update should happen
    # @param [Hash] update_key the key to update the record under
    # @param [Hash] new_record the updated record (all fields!)
    # @param [Hash] old_record the old record (all fields!)
    #
    def update(collection,update_key,new_record,old_record)
      @updates << [collection,update_key,new_record,old_record]
    end

    # Returns arrays of intermediate representations of matched models.
    # Adapters do not have to deal with creating model instances etc.
    #
    # @param [Object] query the query currently not specified...
    def read(query)
      query.call
    end
  end

  # The keylike behaviour of :key_attribute is defined by mapping. 
  # The key_ prefix is only cosmetic here!
  # Simple PORO, but could also be a virtus model, but I'd like to 
  # make sure I do not couple to its API.
  class DomainObject
    attr_accessor :key_attribute,:other_attribute
    def initialize(key_attribute,other_attribute)
      @key_attribute,@other_attribute = key_attribute,other_attribute
    end
  end

  let(:mapper) { DummyMapper.new }
  let(:adapter) { DummyAdapter.new }

  let(:object)       { DomainObject.new(:key_value,"some value") }
  let(:other_object) { DomainObject.new(:other_key,"other value") }

  let(:session) do 
    ::Session::Session.new(
      :mapper => mapper,
      :adapter => adapter
    )
  end

  # broken design
  pending 'when quering objects' do

    subject { session.query(finder) }

    context 'when object could not be found' do
      let(:finder) { lambda { [] } }

      subject { session.query(finder) }

      it 'should return empty array' do
        should == []
      end
    end

    shared_examples_for 'a one object read' do
      it 'should return array of length 1' do
        subject.length.should == 1
      end
     
      it 'should return object' do
        mapper.dump(subject.first).should == mapper.dump(object)
      end
    end

    context 'when object was NOT loaded before' do

      let(:objects) { [object,other_object] }

      context 'when one object is read' do
        let(:finder) { lambda { [mapper.dump(object)] } }
     
        it_should_behave_like 'a one object read'
      end

      context 'when many objects are read' do
        let(:finder) { lambda { objects.map { |o| mapper.dump(o) } } }

        it 'should return array of objects' do
          subject.length.should == objects.length
        end

        it 'should return objects' do
          subject.map { |o| mapper.dump(o) }.should == objects.map { |o| mapper.dump(o) }
        end
      end
    end

    context 'when object was loaded before' do
      before do
        session.insert(object)
        session.commit
      end

      context 'when loaded object is read' do
        let(:finder) { lambda { [mapper.dump(object)] } }

        it_should_behave_like 'a one object read'

        it 'should return the loaded object' do
          subject.first.should == object
        end
      end
    end
  end

  context 'when removing records' do
    before do
      session.insert(object)
      session.commit
    end

    shared_examples 'a delete' do
      before do
        session.delete(object)
        session.commit
      end

      it 'should delete via adapter' do
        adapter.deletes.should == [[:domain_objects,mapper.dump_key(object).fetch(:domain_objects)]]
      end

      it 'should unload the object' do
        session.loaded?(object).should be_false
      end
    end

    context 'when object is not loaded' do
      it 'should raise' do
        expect do
          session.delete(b)
        end.to raise_error
      end
    end

    context 'when object is loaded and not dirty' do
      it 'should mark the object to be deleted' do
        session.delete(object)
        session.delete?(object).should be_true
      end

      it_should_behave_like 'a delete'
    end

    context 'when record is loaded dirty and NOT staged for update' do
      it 'should raise on commit' do
        expect do
          object.key_attribute = :c
          session.delete(object)
          session.commit
        end.to raise_error(RuntimeError,'cannot delete dirty object')
      end
    end

    context 'when record is loaded and staged for update' do
      before do
        session.update(object)
      end

      it 'should raise' do
        expect do
          session.delete(object)
        end.to raise_error
      end
    end
  end

  context 'when updateing objects' do
    context 'when object was not loaded' do 
      it 'should raise' do
        expect do
          session.update(object)
        end.to raise_error
      end
    end

    shared_examples_for 'a update registration' do
      it 'should register an update' do
        session.update?(object).should be_true
      end
    end

    context 'when object was loaded' do
      let!(:object) { DomainObject.new(:a,"some value") }

      before do
        session.insert(object)
        session.commit
      end

      shared_examples_for 'a update commit' do
        before do
          session.commit
        end
     
        it 'should unregister update' do
          session.update?(object).should be_false
        end
      end

      context 'and object was not dirty' do
        before do
          session.update(object)
        end

        it_should_behave_like 'a update registration'

        context 'on commit' do
          it_should_behave_like 'a update commit' do
            it 'should NOT update via the adapter' do
              adapter.updates.should == []
            end
          end
        end
      end

      shared_examples_for 'an update on adapter' do
        before do
          session.commit
        end

        let(:update)     { adapter.updates.first }

        let(:collection) { update[0] }
        let(:key)        { update[1] }
        let(:new_dump)   { update[2] }
        let(:old_dump)   { update[3] }

        it 'should use the correct collection' do
          collection.should == dump_before.keys.first
        end

        it 'should use the correct key' do
          key.should == mapper.load_key(DomainObject,dump_before).fetch(:domain_objects)
        end

        it 'should use the correct old dump' do
          old_dump.should == dump_before.fetch(:domain_objects)
        end

        it 'should use the correct new dump' do
          new_dump.should == mapper.dump(object).fetch(:domain_objects)
        end
      end

      context 'and object was dirty' do
        let!(:dump_before) { mapper.dump(object) }

        context 'on non key' do
          before do
            object.other_attribute = :b
            session.update(object)
          end
         
          it_should_behave_like 'a update registration'
         
          context 'on commit' do
            it_should_behave_like 'a update commit'
            it_should_behave_like 'an update on adapter'
          end
        end

        context 'on key' do
          before do
            object.key_attribute = :b
            session.update(object)
          end
         
          it_should_behave_like 'a update registration'
         
          context 'on commit' do
            it_should_behave_like 'a update commit'
            it_should_behave_like 'an update on adapter'
          end
        end
      end
    end
  end

  context 'when inserting' do
    context 'when object is new' do
      before do
        session.insert(object)
      end
     
      it 'should mark the records as insert' do
        session.insert?(object).should be_true
        session.insert?(other_object).should be_false
      end
     
      it 'should not allow to update the records' do
        expect do
          session.update(object)
        end.to raise_error
      end
     
      context 'when commiting' do
        before do
          session.commit
        end
     
        it 'should send dumped objects to adapter' do
          adapter.inserts.should == [
            [:domain_objects,mapper.dump_value(object)]
          ]
        end
       
        it 'should unmark the records as inserts' do
          session.insert?(object).should be_false
        end
     
        it 'should mark the records as loaded' do
          session.loaded?(object).should be_true
          session.loaded?(other_object).should be_false
        end
      end
    end
  end
end
