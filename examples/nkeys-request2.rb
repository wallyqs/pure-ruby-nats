require 'nats/io/client'

nats = NATS::IO::Client.new
nats.on_error do |e|
  p e
end

# Requires the NKEY seed to be able to sign nonces sent by the server.
seed = "SUADZTYQAKTY5NQM7XRB5XR3C24M6ROGZLBZ6P5HJJSSOFUGC5YXOOECOM"
nats.connect(servers: ["nats://127.0.0.1:4222"], nkeys: seed, name: "nats.account", account: 'nats') # , old_style_request: true)
puts "Connected to #{nats.connected_server}"

# -----------------------------------------------------------

# Prefix matches so forwarded
# nats.subscribe("imports.nats.synadia.>") do |msg, reply, subject|

# This will not work...
# nats.subscribe("imports.nats.synadia.requests") do |msg, reply, subject|
#   puts "Received on '#{subject} #{reply}': #{msg}"
#   nats.publish(reply, "A" * 100) if reply
# end

nats.subscribe("_SECRET_INBOX") do |msg, reply, subject|
  puts "Received on secret inbox! #{msg}"
  nats.publish(reply, "wow") if reply
end

total = 0
payload = 'from nats.io'
loop do
  # nats.publish("hello.#{total}", payload)

  begin
    nats.flush(1)
  
    # Request which waits until given a response or a timeout
    # msg = nats.request("imports.nats.synadia.requests", "hi from nats account! n#{total}")
    # msg = nats.request("synadia.requests", "hi from nats account! n##{total}")
    msg = nats.request("nats.requests", "hi from nats account! n##{total}") rescue nil
    puts "Received on '#{msg.subject} #{msg.reply}': #{msg.data}" unless msg.nil?

    msg = nats.request(msg.reply, "hitting secret inbox!")
    puts "RECEIVED on '#{msg.subject} #{msg.reply}': #{msg.data}" unless msg.nil?

    # This account has no notion of 'synadia.requests' so everything will timeout.
    # msg = nats.request("synadia.requests", "hi from nats account! n##{total}") rescue nil
    # puts "Received on '#{msg.subject} #{msg.reply}': #{msg.data}" unless msg.nil?
  
  rescue NATS::IO::Timeout
    puts "ERROR: timeout"
  end

  total += 1
  sleep 1
end
