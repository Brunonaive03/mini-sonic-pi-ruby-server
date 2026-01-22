require "logger"

module MusicalDSL
  LOGGER = Logger.new($stdout)
  LOGGER.level = Logger::DEBUG
  LOGGER.formatter = proc do |severity, datetime, _progname, msg|
    "[#{datetime.strftime('%Y-%m-%d %H:%M:%S.%3N')}] #{severity.ljust(5)} -- #{msg}\n"
  end
end