class Puppet::HTTP::Service::Report < Puppet::HTTP::Service
  API = '/puppet/v3'.freeze
  EXCLUDED_FORMATS = [:yaml, :b64_zlib_yaml, :dot]

  # puppet major version where JSON is enabled by default
  MAJOR_VERSION_JSON_DEFAULT = 5

  def initialize(client, server, port)
    url = build_url(API, server || Puppet[:report_server], port || Puppet[:report_port])
    super(client, url)
  end

  def put_report(name, report, environment:, ssl_context: nil)
    formatter = Puppet::Network::FormatHandler.format_for(Puppet[:preferred_serialization_format])

    model = Puppet::Transaction::Report
    network_formats = model.supported_formats - EXCLUDED_FORMATS
    mime_types = network_formats.map { |f| model.get_format(f).mime }

    response = @client.put(
      with_base_url("/report/#{name}"),
      headers: add_puppet_headers('ACCEPT' => mime_types.join(', ')),
      params: { :environment => environment },
      content_type: formatter.mime,
      body: formatter.render(report),
      ssl_context: ssl_context
    )

    return response.body.to_s if response.success?

    server_version = response[Puppet::Network::HTTP::HEADER_PUPPET_VERSION]
    if server_version && SemanticPuppet::Version.parse(server_version).major < MAJOR_VERSION_JSON_DEFAULT &&
        Puppet[:preferred_serialization_format] != 'pson'
      #TRANSLATORS "pson", "preferred_serialization_format", and "puppetserver" should not be translated
      raise Puppet::HTTP::ProtocolError.new(_("To submit reports to a server running puppetserver %{server_version}, set preferred_serialization_format to pson") % { server_version: server_version })
    end

    raise Puppet::HTTP::ResponseError.new(response)
  end
end
