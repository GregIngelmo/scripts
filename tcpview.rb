#!/usr/bin/env ruby

# TCP sockets grouped by process 

lsof_result = `sudo lsof -i -P | grep TCP`
#ps_result = `sudo ps aux`
lines = lsof_result.lines.collect { |line| line.split(' ') }
lines_grouped = lines.group_by { |line| line[0] }

lines_grouped.each do |process_info|
  process_name, process_connections = process_info
  print("\x1b[38;5;27m")
  print("#{process_name} (#{process_connections[0][1]})")
  print("\x1b[0m\r\n")
  
  process_connections.each do |process_connection|
    process_name, pid, user_name, 
    file_descripter, ip_type, device_id,
    size, node_type, connections, 
    connection_state = process_connection

    connections = process_connection[-2]
    if connections.include? "->"
      from, from_port, to, to_port = connections.split(/\:|\-\>/)
     
      # ignore connections from localhost to localhost from the same process
      if from.include? 'localhost' and to.include? 'localhost'
        next
      end

      print("\x1b[38;5;69m")
      print("  localhost")
      print("\x1b[0m")
      print(":")
      print("\x1b[38;5;39m")
      print(from_port)
      print("\x1b[0m")

      print(" -> ")

      print("\x1b[38;5;69m")
      print(to)
      print("\x1b[0m")
      print(":")
      print("\x1b[38;5;39m")
      print(to_port)
      print("\x1b[0m")
      
      print("\x1b[38;5;244m")
      print(" #{process_connection[-1]}".downcase)
      print("\x1b[0m")

      puts ""
    else
      puts "  #{process_connection[-2]} #{process_connection[-1]}"
    end
  end
end