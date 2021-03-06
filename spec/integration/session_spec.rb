# encoding: utf-8

require 'spec_helper'

describe 'Session' do
  let(:users)    { TEST_ENV.schema[:users] }
  let(:relation) { TEST_ENV[:users] }
  let(:mapper)   { relation.mapper }
  let(:model)    { mapper.loader.model }

  before do
    users.insert([[1, 'John'], [2, 'Jane']])
  end

  after do
    users.delete([[1, 'John'], [2, 'Jane'], [3, 'Piotr']])
  end

  specify 'fetching an object from a relation' do
    TEST_ENV.session do |session|
      # fetch user for the first time
      jane1 = session[:users].restrict(name: 'Jane').one

      expect(jane1).to eq(model.new(id: 2, name: 'Jane'))

      # here IM-powered loader kicks in
      jane2 = session[:users].restrict(name: 'Jane').one

      expect(jane1).to be(jane2)
    end
  end

  specify 'deleting an object from a relation' do
    TEST_ENV.session do |session|
      jane = session[:users].restrict(name: 'Jane').one

      session[:users].delete(jane)

      session.flush

      expect(relation.to_a).not_to include(jane)
    end
  end

  specify 'saving an object to a relation' do
    TEST_ENV.session do |session|
      piotr = session[:users].new(id: 3, name: 'Piotr')

      session[:users].save(piotr)

      session.flush

      expect(relation.to_a).to include(piotr)
    end
  end

  specify 'updating an object in a relation' do
    TEST_ENV.session do |session|
      jane = session[:users].restrict(id: 2).one
      jane.name = 'Jane Doe'

      session[:users].save(jane)

      session.flush

      expect(relation.count).to be(2)

      expect(relation.to_a.last).to eql(jane)
    end
  end
end
