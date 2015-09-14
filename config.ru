
require 'pp'
require 'rack/builder'
require 'forwardable'

class MiddleOld < Struct.new(:app)
  def call env
    p self.class.name
    status, header, body = app.call(env.merge(self.class.name => 'ENV'))
    [status, header.merge(self.class.name => 'HEAD'), body]
  end
end

class MiddleNew < Struct.new(:app)
  def process_request req, res
    p self.class.name
    # check Rack::App#process_call for why
    res.set_header(self.class.name, 'HEAD')
    # status, header, body = res.call
    # res << "streaming body"
    # res.flush
    Rack::Request2.new(req.env.merge(self.class.name => 'ENV'))
  end
end

module Rack
  RESPONSE = 'rack.response'.freeze
  CALLED   = 'rack.called'  .freeze

  class BodyProxy2 < Struct.new(:response)
    extend Forwardable
    def_delegator :response, :each_body, :each

    # TODO: do we need this for Rack::ContentLength?
    def to_ary
      each.to_a
    end
  end

  class Response2 < Struct.new(:status, :header, :body)
    attr_accessor :env

    # WARN: circular references
    def initialize app, s=200, h={}, b=BodyProxy2.new(self)
      @app = app
      super(s, h, b)
    end

    def calling position
      @position = position
    end

    # to force loading the response body
    def call
    end

    # if some middleware are trying to load the body, this would be called
    # e.g. Rac::ContentLength
    def each_body &block
      b = @app.process(@position, env).last.body
      if block_given?
        b.each(&block)
      else
        b.to_enum
      end
    end

    def set_header key, value
      header[key] = value
    end
  end

  class Request2 < Request
    def called? position
      (env[CALLED] ||= {})[position]
    end

    def called position
      (env[CALLED] ||= {})[position] = true
    end
  end

  class App < Struct.new(:stack)
    def call env
      stack.each.with_index.inject([Request2.new(env), Response2.new(self)],
        &method(:process_call)).last.to_a
    end

    # called by AppProxy and Response2
    def process position, env
      process_call([Request2.new(env), env[RESPONSE]],
                   [stack[position + 1], position + 1])
    end

    private
    def process_call req_res, middle_position
      # hopefully we could do *(req, res) so we don't have to use req_res
      req, res = req_res
      middle, position = middle_position

      if req.called?(position) # TODO: this is a silly hack...
        [req, res]

      else
        req.called(position)
        res.calling(position)

        if middle.respond_to?(:process_request) # new middleware
          # since response would be an action, make sure we're referring to
          # the same object because what we did on response cannot be undone,
          # so it would be confusing if we're generating a new one
          next_req = middle.process_request(req, res)
          res.env = next_req.env # make sure old middleware get latest env
          [next_req, res]

        else # old middleware, which would break the chain...
          # TODO: is there another better way to pass the response object?
          status, header, body = middle.call(req.env.merge(RESPONSE => res))
          res.body = body
          res.status = status
          res.header.merge!(header)
          # make sure old middleware get latest env, which was set from
          # AppProxy#call for old middleware
          [Request2.new(res.env), res]
        end
      end
    end
  end

  class AppProxy < Struct.new(:app, :index)
    def call env
      req, res = app.process(index, env)
      res.env = req.env # make sure old middleware get latest env
      res.to_a
    end
  end

  class Builder2 < Builder
    def to_app
      run = @map ? generate_map(@run, @map) : @run
      fail "missing run or map statement" unless run

      app = App.new # WARN: circular references
      app.stack = @use.map.with_index{ |m, i| m[AppProxy.new(app, i)] } << run

      @warmup.call(app) if @warmup
      app
    end
  end
end

run Rack::Builder2.app{
  use A = Class.new(MiddleNew)
  use B = Class.new(MiddleNew)
  use Rack::ContentType, 'text'
  use C = Class.new(MiddleOld)
  use D = Class.new(MiddleOld)
  # use Rack::ContentLength
  use E = Class.new(MiddleNew)
  use F = Class.new(MiddleOld)
  use G = Class.new(MiddleNew)
  use H = Class.new(MiddleNew)
  use I = Class.new(MiddleNew)
  use J = Class.new(MiddleNew)
  use K = Class.new(MiddleNew)
  use L = Class.new(MiddleNew)
  use M = Class.new(MiddleNew)
  use N = Class.new(MiddleNew)
  run lambda{ |env|
    pp caller
    [200, {}, ["#{env.keys.grep(/\A\w\z/).inspect}\n"]]
  }
}
