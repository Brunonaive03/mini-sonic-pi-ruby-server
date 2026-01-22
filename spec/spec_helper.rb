require 'rspec'

# carregamento dos arquivos da lib (ajuste os caminhos se necessário)
require_relative '../lib/musical_dsl'

RSpec.configure do |c|
  c.order = :defined
  c.disable_monkey_patching!
end
