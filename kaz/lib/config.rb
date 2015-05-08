module Bot

  CONFIG_FILE = File.expand_path '../../../config.yml', __FILE__
  begin
    CONFIG = YAML.load_file CONFIG_FILE
  rescue => e
    STDERR.puts "unable to read: #{CONFIG_FILE}"
    STDERR.puts e
    exit 1
  end

end