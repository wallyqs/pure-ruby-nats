require 'nats/io/client'

nats = NATS::IO::Client.new
nats.on_error do |e|
  p e
end

# Requires the NKEY seed to be able to sign nonces sent by the server.
seed = "SUAKINP3Z2BPUXWOFSW2FZC7TFJCMMU7DHKP2C62IJQUDASOCDSTDTRMJQ"
nats.connect(servers: ["nats://127.0.0.1:4222"], nkeys: seed, name: "cncf.account", account: 'cncf')
puts "Connected to #{nats.connected_server}"

# -----------------------------------------------------------

# nats.subscribe("imports.>") do |msg, reply, subject|
# nats.subscribe("imports.cncf.synadia.>") do |msg, reply, subject|
#   puts "Received on '#{subject} #{reply}': #{msg}"
#   nats.publish(reply, "A" * 100) if reply
# end

total = 0
payload = "from cncf"
loop do
  # nats.publish("hello.#{total}", payload)

  begin
    nats.flush(1)
  
    # Request which waits until given a response or a timeout
    msg = nats.request("synadia.requests", "hi from cncf account! n##{total}")
    puts "Received on '#{msg.subject} #{msg.reply}': #{msg.data}"
  
    msg = nats.request(msg.reply, "hitting secret inbox!")
    puts "RECEIVED on '#{msg.subject} #{msg.reply}': #{msg.data}" unless msg.nil?

    total += 1
  rescue NATS::IO::Timeout
    puts "ERROR: timeout"
  end

  total += 1
  sleep 1
end
