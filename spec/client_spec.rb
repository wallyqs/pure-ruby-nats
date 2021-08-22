# Copyright 2016-2018 The NATS Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'monitor'

describe 'Client - Specification' do

  before(:each) do
    @s = NatsServerControl.new("nats://127.0.0.1:4522")
    @s.start_server(true)
  end

  after(:each) do
    @s.kill_server
    sleep 1
  end

  it 'should connect to locally available server by default' do
    nc = NATS::IO::Client.new
    expect do
      nc.connect(:servers => [@s.uri])
    end.to_not raise_error
    nc.close
  end

  it 'should connect to using a single uri' do
    nc = NATS::IO::Client.new
    expect do
      nc.connect("nats://127.0.0.1:4522")
    end.to_not raise_error
    nc.close
  end

  it 'should received a message when subscribed to a topic' do
    nc = NATS::IO::Client.new
    nc.connect(:servers => [@s.uri])

    msgs = []
    nc.subscribe("hello") do |msg|
      msgs << msg
    end
    sleep 0.5

    1.upto(5) do |n|
      nc.publish("hello", "world-#{n}")
    end
    sleep 0.5

    expect(msgs.count).to eql(5)
    expect(msgs.first.data).to eql('world-1')
    expect(msgs.last.data).to eql('world-5')

    nc.close
  end

  it 'should be able to receive requests synchronously with a timeout' do
    nc = NATS::IO::Client.new
    nc.connect(:servers => [@s.uri])

    received = []
    nc.subscribe("help") do |msg, reply, subject|
      received << msg
      nc.publish(reply, "reply.#{received.count}")
    end
    nc.flush

    responses = []
    responses << nc.request("help", 'please', timeout: 1)
    responses << nc.request("help", 'again', timeout: 1)
    expect(responses.count).to eql(2)
    expect(responses.first[:data]).to eql('reply.1')
    expect(responses.last[:data]).to eql('reply.2')

    nc.close
  end

  it 'should be able to receive limited requests asynchronously' do
    mon = Monitor.new
    done = mon.new_cond

    nc = NATS::IO::Client.new
    nc.connect(:servers => [@s.uri])

    received = []
    nc.subscribe("help") do |msg, reply, subject|
      received << msg
      nc.publish(reply, "reply")
      nc.publish(reply, "back")
      nc.publish(reply, "wont be received")
      nc.publish(reply, "wont be received either")
    end
    nc.flush

    responses = []
    nc.request("help", "please", max: 2) do |msg|
      responses << msg

      if responses.count == 2
        mon.synchronize do
          done.signal
        end
      end
    end

    mon.synchronize do
      done.wait(1)
    end
    nc.close

    expect(received.count).to eql(1)
    expect(responses.count).to eql(2)
    expect(responses[0].data).to eql("reply")
    expect(responses[1].data).to eql("back")
  end

  it 'should be able to unsubscribe' do
    nc = NATS::IO::Client.new
    nc.connect(:servers => [@s.uri], :reconnect => false)

    msgs = []
    sub = nc.subscribe("foo") do |msg|
      msgs << msg
    end
    expect(sub.sid).to eql(1)
    nc.flush

    2.times { nc.publish("foo", "bar") }
    nc.flush

    # Wait for a bit to receive the messages.
    sleep 0.5
    sub.unsubscribe
    nc.flush

    2.times { nc.publish("foo", "bar") }
    nc.flush

    expect(msgs.count).to eql(2)
    nc.close
  end

  it 'should be able to create many subscriptions' do
    # NOTE: After v0.4.0 this means a lot of threads.
    nc = NATS::IO::Client.new
    nc.connect(:servers => [@s.uri])
    max_subs = 50

    msgs = { }
    1.upto(max_subs).each do |n|
      sub = nc.subscribe("quux.#{n}") do |msg, reply, subject|
        msgs[subject] << msg
      end
      nc.flush(1)

      msgs["quux.#{sub.sid}"] = []
    end
    nc.flush(1)

    expect(msgs.keys.count).to eql(max_subs)
    1.upto(max_subs).each do |n|
      nc.publish("quux.#{n}")
    end
    nc.flush(1)

    # Wait a bit for each sub to receive the message.
    sleep 0.5
    1.upto(max_subs).each do |n|
      expect(msgs["quux.#{n}"].count).to eql(1)
    end

    nc.close
  end

  it 'should raise timeout error if timed request does not get response' do
    nc = NATS::IO::Client.new
    nc.connect(:servers => [@s.uri])

    # Have interest but do not respond
    nc.subscribe("hi") { }

    expect do
      nc.request("hi", "timeout", timeout: 1)
    end.to raise_error(NATS::IO::Timeout)

    nc.close
  end

  it 'should close connection gracefully' do
    mon = Monitor.new
    test_is_done = mon.new_cond

    nats = NATS::IO::Client.new
    nats.connect(:servers => [@s.uri], :reconnect => false)

    errors = []
    disconnects = 0
    closes = 0

    nats.on_error do |e|
      errors << e
    end

    nats.on_disconnect do
      disconnects += 1
    end

    nats.on_close do
      closes += 1
      mon.synchronize do
        test_is_done.signal
      end
    end

    msgs = []
    nats.subscribe("bar.>") do |msg|
      msgs << msg
    end
    nats.flush

    pub_thread = Thread.new do
      1.upto(10000).each do |n|
        nats.publish("bar.#{n}", "A" * 10)
      end
      sleep 0.01
      10001.upto(20000).each do |n|
        nats.publish("bar.#{n}", "B" * 10)
      end
    end
    pub_thread.abort_on_exception = true

    nats.close
    mon.synchronize do
      test_is_done.wait(1)
    end

    expect(nats.status).to eql(NATS::IO::CLOSED)
    expect(errors).to be_empty
    expect(disconnects).to eql(1)
    expect(closes).to eql(1)

    # Make sure to kill the publishing thread
    pub_thread.kill
  end

  it "should support distributed queues" do
    conns = Hash.new { |h,k| h[k] = {}}
    5.times do |n|
      nc = NATS::IO::Client.new
      conns[n][:nats] = nc
      conns[n][:msgs] = []

      nc.connect({
        name: "nats-#{n}",
        servers: [@s.uri],
        reconnect: false
      })
      nc.subscribe("foo", queue: 'bar') do |msg|
        conns[n][:msgs] << msg
      end
      nc.flush
    end

    # Publish messages on using the first connection
    nc = conns[0][:nats]
    1000.times do |n|
      nc.publish("foo", 'hi')
    end
    nc.flush

    # Wait more than enough all messages to have been consumed
    sleep 1

    total = 0
    conns.each_pair do |i, conn|
      total += conn[:msgs].count
      expect(conn[:msgs].count > 1).to eql(true)
      conn[:nats].close
    end
    expect(total).to eql(1000)
  end

  context 'using new style request response' do
    it 'should be able to receive requests synchronously with a timeout' do
      nc = NATS::IO::Client.new
      nc.connect(:servers => [@s.uri], :old_style_request => false)

      received = []
      nc.subscribe("help") do |msg, reply, subject|
        received << msg
        nc.publish(reply, "reply.#{received.count}")
      end
      nc.flush

      responses = []
      responses << nc.request("help", 'please', timeout: 1)
      responses << nc.request("help", 'again', timeout: 1)
      expect(responses.count).to eql(2)
      expect(responses.first[:data]).to eql('reply.1')
      expect(responses.last[:data]).to eql('reply.2')

      nc.close
    end

    it 'should be able to receive requests synchronously in parallel' do
      nc = NATS::IO::Client.new
      nc.connect(:servers => [@s.uri], :old_style_request => false)

      received = []
      nc.subscribe("help") do |payload, reply, subject|
        # Echoes the same data back.
        nc.publish(reply, payload)
      end
      nc.flush

      total = 100
      responses_a = []
      t_a = Thread.new do
        sleep 0.2
        total.times do |n|
          responses_a << nc.request("help", "please-A-#{n}", timeout: 0.5)
        end
      end

      responses_b = []
      t_b = Thread.new do
        sleep 0.2
        total.times do |n|
          responses_b << nc.request("help", "please-B-#{n}", timeout: 0.5)
        end
      end

      responses_c = []
      t_c = Thread.new do
        sleep 0.2
        total.times do |n|
          responses_c << nc.request("help", "please-C-#{n}", timeout: 0.5)
        end
      end

      sleep 1
      expect(responses_a.count).to eql(total)
      expect(responses_b.count).to eql(total)
      expect(responses_c.count).to eql(total)

      n = 0
      responses_a.each do |msg|
        expect(msg.data).to eql("please-A-#{n}")
        n += 1
      end

      n = 0
      responses_b.each do |msg|
        expect(msg.data).to eql("please-B-#{n}")
        n += 1
      end

      n = 0
      responses_c.each do |msg|
        expect(msg.data).to eql("please-C-#{n}")
        n += 1
      end

      nc.close
    end
  end

  context "using old style request" do
    it 'should be able to receive responses' do
      mon = Monitor.new
      subscribed_done = mon.new_cond
      test_done = mon.new_cond

      another_thread = Thread.new do
        nats = NATS::IO::Client.new
        nats.connect(:servers => [@s.uri], :reconnect => false)
        nats.subscribe("help") do |msg|
          nats.publish(msg.reply, "response to req:#{msg.data}")
        end
        nats.flush

        mon.synchronize do
          subscribed_done.signal
        end

        mon.synchronize do
          test_done.wait(1)
          # sleep 5
          nats.close
        end

      end

      nc = NATS::IO::Client.new
      nc.connect(:servers => [@s.uri])
      mon.synchronize do
        subscribed_done.wait(1)
      end

      responses = []
      expect do
        3.times do |n|
          response = nil

          response = nc.request("help", "#{n}", timeout: 1, old_style: true)
          responses << response
        end
      end.to_not raise_error
      expect(responses.count).to eql(3)

      # A new subscription would have the next sid for this client.
      sub = nc.subscribe("hello"){ }
      expect(sub.sid).to eql(4)

      mon.synchronize do
        test_done.signal
      end

      responses.each_with_index do |msg, n|
        expect(msg.data).to eql("response to req:#{n}")
      end

      nc.close
      another_thread.exit
    end
  end
end
