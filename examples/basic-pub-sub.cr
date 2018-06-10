require "amqp"
require "signal"

# automatically set a prefix on the exchanges and named queues
# ENV["AMQP_PREFIX"] = ENV["AMQP_PREFIX"] ||= "my-app"
require "../src/amqp-pub-sub"

AMQP::Connection.start(AMQP::Config.new(
  host: ENV["AMQP_HOST"] ||= "localhost", 
  port: (ENV["AMQP_PORT"] ||= "5672").to_i, 
  username: ENV["AMQP_USER"] ||= "guest", 
  password: ENV["AMQP_PASS"] ||= "guest"
)) do |conn|
  puts "connected to the AMQP server"
  conn.on_close do |code, msg|
    puts "connection to the AMQP server closed: #{code} - #{msg}"
  end

  publisherWarning = Messaging::Publisher.new(conn, "direct_logs", "warning", "direct")
  publisherError = Messaging::Publisher.new(conn, "direct_logs", "error", "direct")

  subscriberWarning = Messaging::Subscriber.new(conn, "direct_logs", "warning", "direct")
  subscriberWarning.queue(exclusive: true, auto_delete: true).subscribe do |msg|
    puts "received: #{msg.to_s}"
    msg.ack
  end
  subscriberError = Messaging::Subscriber.new(conn, "direct_logs", "error", "direct")
  subscriberError.queue(exclusive: true, auto_delete: true).subscribe do |msg|
    puts "received: #{msg.to_s}"
    msg.ack
  end

  10.times do |i| 
    publisherWarning.publish("{\"type\": \"warning\", \"id\": #{i + 1}}")
    publisherError.publish("{\"type\": \"error\", \"id\": #{i + 1}}")
  end

  puts "exit the program with CTRL ^C"
  Signal::INT.trap do
    puts "\nexiting..."
    conn.loop_break
    Messaging.dispose_all
  end
  conn.run_loop
end
