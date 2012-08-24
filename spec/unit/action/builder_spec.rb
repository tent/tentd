require 'spec_helper'

class TestMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    env[:test] ||= 0
    env[:test] += 1
    @app.call(env)
  end
end

describe TentServer::Action::Builder do
  let(:instance) { described_class.new }

  context "basic `use`" do
    it "should add items to the stack" do
      instance.use TestMiddleware
      env = instance.call({})
      expect(env[:test]).to eq(1)
    end

    it "should add multiple items to the stack" do
      instance.use TestMiddleware
      instance.use TestMiddleware
      env = instance.call({})
      expect(env[:test]).to eq(2)
    end
  end
end
