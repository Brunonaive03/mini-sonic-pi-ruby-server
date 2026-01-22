$stdout.sync = true

require "sinatra/base"
require "json"
require "rack/cors"
require_relative "lib/musical_dsl"


class MusicalDSLServer < Sinatra::Base
  disable :protection
  
  set :bind, "0.0.0.0"
  set :port, 4567
  
  use Rack::Cors do
    allow do
      origins '*' # Mantenha '*' por enquanto para testes entre localhost e Railway
      resource '*',
        headers: :any,
        methods: [:get, :post, :options],
        expose: ['Content-Type', 'Authorization'], # Exponha headers se necessário
        max_age: 600
    end
  end

  post "/run" do
    code = request.body.read
    MusicalDSL::LOGGER.info("[SERVER:POST /run] Received #{code.length} bytes of code")

    if code.nil? || code.strip.empty?
      MusicalDSL::LOGGER.warn("[SERVER:POST /run] Code was empty")
      status 400
      return { error: "Código DSL vazio" }.to_json
    end

    MusicalDSL::LOGGER.debug("[SERVER:POST /run] Code:\n#{code}")

    runtime = MusicalDSL::Runtime.new
    runtime_id = MusicalDSL::Runtime.register(runtime)
    MusicalDSL::LOGGER.info("[SERVER:POST /run] Runtime registered with id=#{runtime_id}")
    
    runtime.start(code)

    MusicalDSL::LOGGER.info("[SERVER:POST /run] Runtime started, returning 202")

    content_type :json
    status 202
    { runtime_id: runtime_id }.to_json
  rescue => e
    MusicalDSL::LOGGER.error("[SERVER:POST /run:ERROR] #{e.class}: #{e.message}")
    MusicalDSL::LOGGER.debug("[SERVER:POST /run:ERROR] #{e.backtrace.join("\n")}")
    status 500
    content_type :json
    { error: "internal", message: e.message }.to_json
  end

  # POST /stop { "runtime_id": N }
  post "/stop" do
    begin
      payload = request.body.read
      data = payload && payload.strip != "" ? JSON.parse(payload) : {}
    rescue JSON::ParserError => e
      MusicalDSL::LOGGER.warn("[SERVER:POST /stop] JSON parse error: #{e.message}")
      data = {}
    end

    runtime_id = data["runtime_id"] || params["runtime_id"]
    MusicalDSL::LOGGER.info("[SERVER:POST /stop] Stop requested for runtime_id=#{runtime_id}")
    
    unless runtime_id
      MusicalDSL::LOGGER.warn("[SERVER:POST /stop] No runtime_id provided")
      status 400
      return { error: "runtime_id required" }.to_json
    end

    runtime = MusicalDSL::Runtime.fetch(runtime_id.to_i)
    unless runtime
      MusicalDSL::LOGGER.warn("[SERVER:POST /stop] Runtime not found (id=#{runtime_id})")
      status 404
      return { error: "runtime not found", runtime_id: runtime_id }.to_json
    end

    MusicalDSL::LOGGER.info("[SERVER:POST /stop] Stopping runtime (id=#{runtime_id}")
    runtime.stop
    MusicalDSL::Runtime.unregister(runtime_id.to_i)

    MusicalDSL::LOGGER.info("[SERVER:POST /stop] Runtime stopped (id=#{runtime_id}")

    content_type :json
    { status: "stopped", runtime_id: runtime_id.to_i }.to_json
  end

  # GET /events?runtime_id=ID&since_id=NN
  get "/events" do
    runtime_id = params["runtime_id"]&.to_i
    since_id = params["since_id"] ? params["since_id"].to_i : 0

    MusicalDSL::LOGGER.debug("[SERVER:GET /events] runtime_id=#{runtime_id} since_id=#{since_id}")

    unless runtime_id
      MusicalDSL::LOGGER.warn("[SERVER:GET /events] No runtime_id provided")
      status 400
      return { error: "runtime_id query param required" }.to_json
    end

    runtime = MusicalDSL::Runtime.fetch(runtime_id)
    unless runtime
      MusicalDSL::LOGGER.warn("[SERVER:GET /events] Runtime not found (id=#{runtime_id})")
      status 404
      return { error: "runtime not found", runtime_id: runtime_id }.to_json
    end

    alive = runtime.alive?
    events = runtime.events_since(since_id)
    MusicalDSL::LOGGER.debug("[SERVER:GET /events] Returning #{events.length} events (alive=#{alive})")

    content_type :json
    {
      runtime_id: runtime_id,
      events: events,
      last_id: events.empty? ? since_id : events.last["id"],
      alive: alive
    }.to_json
  rescue => e
    MusicalDSL::LOGGER.error("[SERVER:GET /events:ERROR] #{e.class}: #{e.message}")
    status 500
    content_type :json
    { error: "internal", message: e.message }.to_json
  end
end

MusicalDSL::LOGGER.info("[BOOT] MusicalDSLServer starting on 0.0.0.0:4567")
MusicalDSLServer.run! if __FILE__ == $0