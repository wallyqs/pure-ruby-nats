require 'nats/io/client'

$stdout.sync = true
nats = NATS::IO::Client.new

nats.on_reconnect do
  puts "Reconnected to server at #{nats.connected_server}"
end

nats.on_disconnect do
  puts "Disconnected!"
end

nats.on_close do
  puts "Connection to NATS closed"
end

nats.on_error do |e|
  puts "Error: #{e}"
  puts e.backtrace
end

servers = ["nats://127.0.0.1:4222", "nats://127.0.0.1:4223"]

cluster_opts = {
  servers: servers,
  reconnect_time_wait: 1,
  max_reconnect_attempts: -1, # Infinite reconnects
  ping_interval: 10,
  dont_randomize_servers: true,
  connect_timeout: 2
}

puts "Attempting to connect to #{servers.first}..."
nats.connect(cluster_opts)

puts "Connected to #{nats.connected_server}"

msgs_sent = 0
msgs_received = 0
bytes_sent = 0
bytes_received = 0

nats.subscribe("hello") {|data| msgs_received += 1; bytes_received += data.size }

Thread.new do
  loop do
    puts "#{Time.now} #{Thread.list.count} - [Sent/Received] #{msgs_sent}/#{msgs_received} msgs (#{msgs_sent - msgs_received}) | [Received] #{bytes_sent}/#{bytes_received} B (#{bytes_sent - bytes_received})"
    sleep 1
  end
end

loop do
  sleep 0.00001

  payload = "world.#{msgs_sent}"
  nats.publish("hello", payload)
  msgs_sent += 1
  bytes_sent += payload.size
end
