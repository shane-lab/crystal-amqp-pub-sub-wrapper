require "amqp"

require "./disposable"

AMQP_PREFIX = ENV["AMQP_PREFIX"] ||= nil
AMQP_PREFIX = AMQP_PREFIX ? "#{AMQP_PREFIX}." : ""

module Messaging
    @@disposables = Set(Disposable).new

    protected def self.append_disposable(disposable : Disposable)
        @@disposables.add(disposable)
    end
    
    class Publisher < Disposable
        @channel : AMQP::Channel?
        def initialize(@connection : AMQP::Connection)
            Messaging.append_disposable(self)
        end

        def publish(data : String, router : String, key : String, type = "topic")
            ch = @channel = @connection.channel

            message = AMQP::Message.new(data)
            
            exchange = ch.exchange("#{AMQP_PREFIX}#{router}", type)
            exchange.publish(message, "#{AMQP_PREFIX}#{key}")
        end

        def dispose
            ch = @channel
            if (ch.is_a? AMQP::Channel)
                ch.close
            end
        end
    end
    
    class Subscriber < Disposable
        @unbind = true
        @channel : AMQP::Channel?
        @queue : AMQP::Queue?
        @exchange : AMQP::Exchange?
        def initialize(
            @connection : AMQP::Connection,
            @router : String,
            @key : String,
            @type = "topic"
        )
            Messaging.append_disposable(self)
        end

        def queue(durable = false, passive = false, exclusive = false, auto_delete = false)
            ch = @channel = @connection.channel

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
            ch = @channel
            if (ch.is_a? AMQP::Channel)
                ch.close
            end
        ensure
            @queue = nil
        end
    end

    def self.dispose_all
        @@disposables.each do |disposable|
            disposable.dispose
        end
    end
end
