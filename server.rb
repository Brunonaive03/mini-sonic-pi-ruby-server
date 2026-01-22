$stdout.sync = true

require "sinatra/base"
require "json"
require "rack/cors"
require_relative "lib/musical_dsl"

class MusicalDSLServer < Sinatra::Base
  # Configurações básicas
  set :bind, "0.0.0.0"
  set :port, ENV["PORT"] || 4567

  ########################################
  # CORS — obrigatório para produção
  ########################################
  use Rack::Cors do
    allow do
      origins '*'
      resource '*',
        headers: :any,
        methods: [:get, :post, :options],
        expose: ['Content-Type'],
        max_age: 600
    end
  end

  # Preflight explícito (Railway / browsers)
  options "*" do
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    200
  end

  ########################################
  # POST /run
  ########################################
  post "/run" do
    code = request.body.read
    MusicalDSL::LOGGER.info("[SERVER:POST /run] Received #{code.length} bytes of code")

    if code.nil? || code.strip.empty?
      MusicalDSL::LOGGER.warn("[SERVER:POST /run] Code was empty")
      status 400
      content_type :json
      return { error: "Código DSL vazio" }.to_json
    end

    MusicalDSL::LOGGER.debug("[SERVER:POST /run] Code:\n#{code}")

    runtime = MusicalDSL::Runtime.new
    runtime_id = MusicalDSL::Runtime.register(runtime)

    MusicalDSL::LOGGER.info("[SERVER:POST /run] Runtime registered (id=#{runtime_id})")

    runtime.start(code)

    MusicalDSL::LOGGER.info("[SERVER:POST /run] Runtime started")

    status 202
    content_type :json
    { runtime_id: runtime_id }.to_json

  rescue => e
    MusicalDSL::LOGGER.error("[SERVER:POST /run:ERROR] #{e.class}: #{e.message}")
    MusicalDSL::LOGGER.debug("[SERVER:POST /run:ERROR]\n#{e.backtrace.join("\n")}")
    status 500
    content_type :json
    { error: "internal", message: e.message }.to_json
  end

  ########################################
  # POST /stop
  ########################################
  post "/stop" do
    begin
      payload = request.body.read
      data = payload && !payload.strip.empty? ? JSON.parse(payload) : {}
    rescue JSON::ParserError => e
      MusicalDSL::LOGGER.warn("[SERVER:POST /stop] JSON parse error: #{e.message}")
      data = {}
    end

    runtime_id = data["runtime_id"] || params["runtime_id"]

    MusicalDSL::LOGGER.info("[SERVER:POST /stop] Stop requested for runtime_id=#{runtime_id}")

    unless runtime_id
      status 400
      content_type :json
      return { error: "runtime_id required" }.to_json
    end

    runtime = MusicalDSL::Runtime.fetch(runtime_id.to_i)

    unless runtime
      status 404
      content_type :json
      return { error: "runtime not found", runtime_id: runtime_id }.to_json
    end

    runtime.stop
    MusicalDSL::Runtime.unregister(runtime_id.to_i)

    MusicalDSL::LOGGER.info("[SERVER:POST /stop] Runtime stopped (id=#{runtime_id})")

    content_type :json
    { status: "stopped", runtime_id: runtime_id.to_i }.to_json
  end

  ########################################
  # GET /events
  ########################################
  get "/events" do
    runtime_id = params["runtime_id"]&.to_i
    since_id  = params["since_id"] ? params["since_id"].to_i : 0

    MusicalDSL::LOGGER.debug(
      "[SERVER:GET /events] runtime_id=#{runtime_id} since_id=#{since_id}"
    )

    unless runtime_id
      status 400
      content_type :json
      return { error: "runtime_id query param required" }.to_json
    end

    runtime = MusicalDSL::Runtime.fetch(runtime_id)

    unless runtime
      status 404
      content_type :json
      return { error: "runtime not found", runtime_id: runtime_id }.to_json
    end

    events = runtime.events_since(since_id)
    alive  = runtime.alive?

    MusicalDSL::LOGGER.debug(
      "[SERVER:GET /events] Returning #{events.length} events (alive=#{alive})"
    )

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

MusicalDSL::LOGGER.info("[BOOT] MusicalDSLServer starting")
MusicalDSLServer.run! if __FILE__ == $0
