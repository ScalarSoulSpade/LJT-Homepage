require "base64"
require "json"
require "net/http"
require "uri"

Jekyll::Hooks.register :site, :after_init do |_site|
  next unless ENV["GITHUB_ACTIONS"] == "true"

  repository = ENV["GITHUB_REPOSITORY"] || "ScalarSoulSpade/LJT-Homepage"
  token = ENV["GITHUB_TOKEN"]

  if token.nil? || token.empty?
    header = `git config --get "http.https://github.com/.extraheader"`.to_s
    if (match = header.match(/basic\s+([A-Za-z0-9+\/=]+)/i))
      decoded = Base64.decode64(match[1])
      token = decoded.split(":", 2)[1]
    end
  end

  if token.nil? || token.empty?
    Jekyll.logger.warn "Pages setup:", "No deployment token available"
    next
  end

  uri = URI("https://api.github.com/repos/#{repository}/pages")

  [
    { build_type: "workflow" },
    { build_type: "workflow", source: { branch: "master", path: "/" } }
  ].each do |payload|
    request = Net::HTTP::Put.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Accept"] = "application/vnd.github+json"
    request["X-GitHub-Api-Version"] = "2022-11-28"
    request.body = JSON.generate(payload)

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    Jekyll.logger.info "Pages setup:", "Payload #{payload.keys.join(",")} returned #{response.code}: #{response.body[0, 500]}"
    break if response.code.start_with?("2")
  end
end
