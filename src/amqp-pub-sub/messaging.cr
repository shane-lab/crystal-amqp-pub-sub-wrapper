require "amqp"

require "./disposable"

ENV_AMQP_PREFIX = ENV["AMQP_PREFIX"] ||= nil
AMQP_PREFIX = ENV_AMQP_PREFIX ? "#{ENV["AMQP_PREFIX"]}." : ""

module Messaging
    @@disposables = Set(Disposable).new

    protected def self.append_disposable(disposable : Disposable)
        @@disposables.add(disposable)
    end
    
    class Publisher < Disposable
        @channel : AMQP::Channel
        @exchange : AMQP::Exchange
        def initialize(@connection : AMQP::Connection, @router : String, @key : String, type = "topic", durable = false, passive = false, no_wait = false, internal = false, auto_delete = false, args = AMQP::Protocol::Table.new)
            @channel = @connection.channel
            @exchange = @channel.exchange(
                name: "#{AMQP_PREFIX}#{@router}", 
                kind: type, 
                args: args,
                durable: durable,
                internal: internal,
                no_wait: no_wait,
                auto_delete: auto_delete
            )
            Messaging.append_disposable(self)
        end

        def publish(data : String, properties = AMQP::Protocol::Properties.new)
            @exchange.publish(AMQP::Message.new(data, properties), "#{AMQP_PREFIX}#{@key}")
        end

        def dispose
            @channel.close
        end
    end
    
    class Subscriber < Disposable
        @unbind = true
        @channel : AMQP::Channel
        @queue : AMQP::Queue?
        @exchange : AMQP::Exchange?
        def initialize(
            @connection : AMQP::Connection,
            @router : String,
            @key : String,
            @type = "topic"
        )
            @channel = @connection.channel
            Messaging.append_disposable(self)
        end

        def queue(durable = false, passive = false, exclusive = false, auto_delete = false)
            ch = @channel #= @connection.channel

            ex = @exchange = ch.exchange("#{AMQP_PREFIX}#{@router}", @type)
            name = "#{AMQP_PREFIX}#{@key}"
            q = @queue = ch.queue(
                name: exclusive ? "" : name,
                durable: durable,
                passive: passive,
                exclusive: exclusive,
                auto_delete: auto_delete
                )
            q.bind(ex, q.name)
            if (exclusive)
                q.bind(ex, name)
            end
            @unbind = auto_delete ? true : exclusive
            
            q
        end

        def dispose
            ex = @exchange
            q = @queue
            if (@unbind && q.is_a? AMQP::Queue && ex.is_a? AMQP::Exchange)
                q.unbind(ex, q.name)
            end
        ensure
            @channel.close
            @queue = nil
        end
    end

    def self.dispose_all
        @@disposables.each do |disposable|
            disposable.dispose
        end
    end
end
