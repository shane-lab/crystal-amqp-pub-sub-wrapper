require "amqp"
require "signal"

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

  publisher = Messaging::Publisher.new(conn)

  subscriber = Messaging::Subscriber.new(conn, "direct_logs", "warning", "direct")
  subscriber.queue(exclusive: true, auto_delete: true).subscribe do |msg|
    puts "received: #{msg.to_s}"
    msg.ack
  end
  subscriber1 = Messaging::Subscriber.new(conn, "direct_logs", "error", "direct")
  subscriber1.queue(exclusive: true, auto_delete: true).subscribe do |msg|
    puts "received: #{msg.to_s}"
    msg.ack
  end

  10.times do |i| 
    publisher.publish("{\"type\": \"warning\", \"id\": #{i + 1}}", "direct_logs", "warning", "direct")
    publisher.publish("{\"type\": \"error\", \"id\": #{i + 1}}", "direct_logs", "error", "direct")
  end

  puts "program finished. exit with CTRL ^C"
  Signal::INT.trap do
    puts "\nexiting..."
    conn.loop_break
    Messaging.dispose_all
  end
  conn.run_loop
end
