module Config

export load, get_value

# Default configuration
const DEFAULT_CONFIG = Dict(
    "server" => Dict(
        "host" => "localhost",
        "port" => 8052,
        "workers" => 4,
        "log_level" => "info"
    ),
    "storage" => Dict(
        "local_db_path" => joinpath(homedir(), ".arvoos", "arvoos.sqlite"),
        "arweave_wallet_file" => get(ENV, "ARWEAVE_WALLET_FILE", ""),
        "arweave_gateway" => get(ENV, "ARWEAVE_GATEWAY", "arweave.net"),
        "arweave_port" => parse(Int, get(ENV, "ARWEAVE_PORT", "443")),
        "arweave_protocol" => get(ENV, "ARWEAVE_PROTOCOL", "https"),
        "arweave_timeout" => parse(Int, get(ENV, "ARWEAVE_TIMEOUT", "20000")),
        "arweave_logging" => parse(Bool, get(ENV, "ARWEAVE_LOGGING", "false"))
    ),
    "blockchain" => Dict(
        "default_chain" => "ethereum",
        "rpc_urls" => Dict(
            "ethereum" => "https://mainnet.infura.io/v3/YOUR_API_KEY",
            "polygon" => "https://polygon-rpc.com",
            "solana" => "https://api.mainnet-beta.solana.com"
        ),
        "max_gas_price" => 100.0,
        "max_slippage" => 0.01,
        "supported_chains" => ["ethereum", "polygon", "solana"]
    ),
    "swarm" => Dict(
        "default_algorithm" => "DE",
        "default_population_size" => 50,
        "max_iterations" => 1000,
        "parallel_evaluation" => true
    ),
    "security" => Dict(
        "rate_limit" => 100,
        "max_request_size" => 1048576,
        "enable_authentication" => false
    ),
    "bridge" => Dict(
        "port" => 8052,
        "host" => "localhost",
        "bridge_api_url" => "http://localhost:3001/api/v1"
    ),
    "wormhole" => Dict(
        "enabled" => true,
        "network" => "testnet",
        "networks" => Dict(
            "ethereum" => Dict(
                "rpcUrl" => "https://goerli.infura.io/v3/your-infura-key",
                "enabled" => true
            ),
            "solana" => Dict(
                "rpcUrl" => "https://api.devnet.solana.com",
                "enabled" => true
            )
        )
    ),
    "logging" => Dict(
        "level" => "info",
        "format" => "json",
        "retention_days" => 7
    )
)

# Configuration object with dot notation access
struct Configuration
    data::Dict{String, Any}

    function Configuration(data::Dict)
        new(convert(Dict{String, Any}, data))
    end

    function Base.getproperty(config::Configuration, key::Symbol)
        key_str = String(key)
        if key_str == "data"
            return getfield(config, :data)
        elseif haskey(config.data, key_str)
            value = config.data[key_str]
            if value isa Dict{String, Any}
                return Configuration(value)
            else
                return value
            end
        else
            error("Configuration key not found: $key_str")
        end
    end

    function Base.haskey(config::Configuration, key::Symbol)
        key_str = String(key)
        return haskey(config.data, key_str)
    end
end

function load(config_path=nothing)
    config_data = deepcopy(DEFAULT_CONFIG)

    if !isnothing(config_path) && isfile(config_path)
        try
            file_config = Dict{String, Any}()
            merge_configs!(config_data, file_config)
        catch e
            @warn "Error loading configuration file: $e"
        end
    elseif isfile(joinpath(@__DIR__, "config.toml"))
        try
            file_config = Dict{String, Any}()
            merge_configs!(config_data, file_config)
        catch e
            @warn "
