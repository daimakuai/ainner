require "thor"
require "listen"

module Ainner
  class Command < Thor
    include Thor::Actions
    map "-v" => :version

    def self.source_root
      File.dirname(__FILE__)
    end

    desc "version", "show version"
    def version
      puts Ainner::VERSION
    end

    desc "check", "check dependencies"
    method_option :environment,
                  type: :string,
                  default: "development",
                  aliases: "-e",
                  desc: "Watch the choosen environment"
    def check
      env.merge_with_environment(options[:environment])
      message = Ainner::Bundler.new(env).check
      puts (message.first ? "🍵 :" : "👻 :") + message.last
    end

    desc "install", "install dependencies"
    method_option :environment,
                  type: :string,
                  default: "development",
                  aliases: "-e",
                  desc: "Watch the choosen environment"
    def install
      begin
        env.merge_with_environment(options[:environment])
        Ainner::Bundler.new(env).perform
      rescue
        puts "👻 : Install failed!"
        puts $!
        return
      end
      puts "🍵 : Perfect installed all bundles!"
    end

    desc "build", "build assets"
    method_option :strict,
                  type: :boolean,
                  default: false,
                  aliases: "-s",
                  desc: "Use strict mode to replace revisiton."
    method_option :environment,
                  type: :string,
                  default: "production",
                  aliases: "-e",
                  desc: "Build the choosen environment"
    def build
      Ainner.compile = true
      Ainner.strict = true if options[:strict]
      clean
      env.merge_with_environment(options[:environment])
      Bundler.new(env).perform
      perform(build: true)
    end

    desc "watch", "watch assets"
    method_option :environment,
                  type: :string,
                  default: "development",
                  aliases: "-e",
                  desc: "Watch the choosen environment"
    def watch
      clean
      env.merge_with_environment(options[:environment])
      Bundler.new(env).perform
      perform
      watch_for_env
      watch_for_perform
      watch_for_reload rescue nil
      sleep
    end

    desc "clean", "clean assets"
    def clean
      FileUtils.rm_rf Dir.glob("#{env.public_folder}/*")
    end

    desc "new", "create the skeleton of project"
    def new(name)
      directory('templates', name)
      chmod("#{name}/bin/server", 0755)
    end

  private
    def env
      Ainner.env
    end

    def perform(build: false)
      Notifier.profile { Ainner.perform }
    rescue
      build ? Notifier.error($!) : Notifier.notify($!)
    end

    def watch_for_perform
      Listen.to env.watched_paths do |modified, added, removed|
        Ainner.cache.expire_by(modified + added + removed)
        perform
      end
    end

    def watch_for_reload
      reactor = Reactor.supervise_as(:reactor).actors.first
      Listen.to env.public_folder, relative_path: true do |modified, added, removed|
        reactor.reload_browser(modified + added + removed)
      end
    end

    def watch_for_env
      Listen.to Ainner.root, filter: /(config\.yml|Ainnerfile)$/ do |modified, added, removed|
        Ainner.env = Environment.new Ainner.config_file
        Bundler.new(env).perform
      end
    end

    def exit!
      Notifier.exit
      Kernel::exit
    end
  end
end
