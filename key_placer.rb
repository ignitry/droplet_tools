require 'droplet_kit'
require 'net/ssh'

client = DropletKit::Client.new(access_token: ENV['DIGITALOCEAN_ACCESS_TOKEN'])

droplets = client.droplets.all

ips = droplets.map do |droplet|
        droplet.networks.v4.find do |n|
          n.type == 'public'
        end&.ip_address
      end.compact

key_file_path = ENV['SSH_PUBLIC_KEY_FILE_PATH']
keys = File.read(key_file_path).split("\n")

SSH_TIMEOUT = 10

ips.each do |ip|
  keys.each do |key|
    begin
      Net::SSH.start(ip, 'root', keys: [ENV['DEPLOY_KEY_PATH']], verify_host_key: :never, timeout: SSH_TIMEOUT) do |ssh|
        # Check if the key is already in the authorized_keys
        unless ssh.exec!("grep -Fx '#{key}' ~/.ssh/authorized_keys")
          ssh.exec!("echo '#{key}' >> ~/.ssh/authorized_keys")
        end
      end
    rescue Net::SSH::AuthenticationFailed, Net::SSH::Disconnect => e
      puts "Failed to connect to #{ip}: #{e.message}"
    rescue Net::SSH::ConnectionTimeout => e
      puts "Connection Timeout #{ip}: #{e.message}"
    end
  end
end
