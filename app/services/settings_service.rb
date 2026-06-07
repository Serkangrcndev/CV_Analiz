require 'json'
require 'fileutils'

class SettingsService
  SETTINGS_FILE = File.join(APP_ROOT, 'config', 'settings.json')

  def self.load_settings
    if File.exist?(SETTINGS_FILE)
      begin
        JSON.parse(File.read(SETTINGS_FILE))
      rescue => e
        warn "Failed to parse settings.json: #{e.message}"
        {}
      end
    else
      default = {
        "active_model" => "local",
        "grok_api_key" => ""
      }
      begin
        FileUtils.mkdir_p(File.dirname(SETTINGS_FILE))
        File.write(SETTINGS_FILE, JSON.pretty_generate(default))
      rescue => e
        warn "Failed to write default settings.json: #{e.message}"
      end
      default
    end
  end

  def self.active_model
    load_settings['active_model'] || 'local'
  end

  def self.grok_key
    key = load_settings['grok_api_key']
    key.nil? || key.strip.empty? || key.include?("your_grok_key") ? nil : key.strip
  end
end
