defmodule DdexDeliveryServiceWeb.FeaturesLive do
  use DdexDeliveryServiceWeb, :live_view

  @tenant_code """
  # API key is scoped to an organization
  # The X-Organization-Id header selects the tenant

  curl -H "Authorization: Bearer dds_abc123..." \\
       -H "X-Organization-Id: org_spotify" \\
       https://your-instance.fly.dev/api/json/releases\
  """

  @api_key_code """
  # Create a key via the dashboard, then use it:

  curl -X GET \\
       -H "Authorization: Bearer dds_live_a1b2c3d4e5f6..." \\
       -H "Content-Type: application/vnd.api+json" \\
       https://your-instance.fly.dev/api/json/releases\
  """

  @dual_api_code """
  # JSON:API — list releases with artist included
  curl -H "Authorization: Bearer dds_..." \\
       "/api/json/releases?include=artists&filter[title]=Abbey+Road"

  # GraphQL — query releases with tracks
  curl -X POST /gql \\
       -H "Authorization: Bearer dds_..." \\
       -H "Content-Type: application/json" \\
       -d '{"query": "{ releases { title tracks { title isrc } } }"}'
  """

  @ern_code """
  <!-- ERN 4.3 — auto-detected from namespace -->
  <ern:NewReleaseMessage
    xmlns:ern="http://ddex.net/xml/ern/43">
    <ReleaseList>
      <Release>
        <ReleaseId>
          <ICPN>00602445073658</ICPN>
        </ReleaseId>
        <ReferenceTitle>Abbey Road</ReferenceTitle>
        ...
      </Release>
    </ReleaseList>
  </ern:NewReleaseMessage>\
  """

  @storage_code """
  # Files are stored under tenant-isolated paths:

  tenants/org_spotify/deliveries/abc123/
    ├── message.xml
    ├── audio/
    │   ├── track_01.flac
    │   └── track_02.flac
    └── artwork/
        └── cover.jpg

  # Presigned URLs provide time-limited access
  # without exposing storage credentials\
  """

  @realtime_code """
  # Delivery lifecycle:
  #
  # 1. Upload    → Files received, delivery created
  # 2. Parsing   → XML validated, version detected
  # 3. Ingesting → Releases, tracks, artists extracted
  # 4. Complete  → Data available via API
  #
  # Each step broadcasts via PubSub:
  # "delivery:<id>" → %{status: :parsing}
  # "delivery:<id>" → %{status: :complete}\
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Features — DDEX Delivery Service",
       tenant_code: @tenant_code,
       api_key_code: @api_key_code,
       dual_api_code: @dual_api_code,
       ern_code: @ern_code,
       storage_code: @storage_code,
       realtime_code: @realtime_code
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <%!-- Hero --%>
      <section class="py-20 sm:py-28">
        <div class="mx-auto max-w-4xl px-6 text-center">
          <h1 class="text-4xl sm:text-6xl font-bold tracking-tight text-base-content">
            Built for secure
            <span class="text-primary">music delivery</span>
          </h1>
          <p class="mt-6 text-lg sm:text-xl text-base-content/70 max-w-2xl mx-auto leading-relaxed">
            Multi-tenant isolation, API key auth, dual APIs, DDEX parsing, and secure file storage &mdash; everything a DSP needs to receive and serve catalog data.
          </p>
        </div>
      </section>

      <%!-- Tenant Isolation --%>
      <.feature_section id="tenant-isolation" bg="bg-base-200/50">
        <:icon><.icon name="hero-shield-check" class="size-8 text-primary" /></:icon>
        <:title>Tenant Isolation</:title>
        <:description>
          <p>Every organization operates in a fully isolated environment. Attribute-based multi-tenancy ensures every query is automatically scoped to the current tenant &mdash; no data leaks between stores, ever.</p>
          <ul class="mt-4 space-y-2 text-base-content/70">
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Automatic query scoping per organization</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Pre-release content isolation between stores</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>API keys scoped to their owning organization</span>
            </li>
          </ul>
        </:description>
        <:code>
          <.code_block title="API request scoped to organization" code={@tenant_code} />
        </:code>
      </.feature_section>

      <%!-- API Key Authentication --%>
      <.feature_section id="api-key-auth">
        <:icon><.icon name="hero-key" class="size-8 text-primary" /></:icon>
        <:title>API Key Authentication</:title>
        <:description>
          <p>Create scoped API keys for each organization. Keys support granular permissions so you can grant exactly the access level needed.</p>
          <ul class="mt-4 space-y-2 text-base-content/70">
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Bearer token auth: <code class="bg-base-300 px-1.5 py-0.5 rounded text-sm">Authorization: Bearer dds_...</code></span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Granular scopes: read, write, admin</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Expiration support and last-used tracking</span>
            </li>
          </ul>
        </:description>
        <:code>
          <.code_block title="Authenticating with an API key" code={@api_key_code} />
        </:code>
      </.feature_section>

      <%!-- Dual API Layer --%>
      <.feature_section id="dual-api" bg="bg-base-200/50">
        <:icon><.icon name="hero-code-bracket" class="size-8 text-primary" /></:icon>
        <:title>Dual API Layer</:title>
        <:description>
          <p>Access your catalog through whichever protocol fits your stack. Both APIs are generated from the same Ash resource definitions, so they stay perfectly in sync.</p>
          <ul class="mt-4 space-y-2 text-base-content/70">
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>JSON:API (REST) with Swagger/OpenAPI docs at <code class="bg-base-300 px-1.5 py-0.5 rounded text-sm">/api/json/swaggerui</code></span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>GraphQL with playground at <code class="bg-base-300 px-1.5 py-0.5 rounded text-sm">/gql/playground</code></span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Filter, sort, and paginate on any field</span>
            </li>
          </ul>
        </:description>
        <:code>
          <.code_block title="JSON:API and GraphQL examples" code={@dual_api_code} />
        </:code>
      </.feature_section>

      <%!-- DDEX Parsing --%>
      <.feature_section id="ddex-parsing">
        <:icon><.icon name="hero-document-check" class="size-8 text-primary" /></:icon>
        <:title>DDEX ERN Parsing</:title>
        <:description>
          <p>Upload any ERN XML and we handle the rest. Automatic version detection means you don't need to know whether a label sends 3.8.2 or 4.3 &mdash; both work seamlessly.</p>
          <ul class="mt-4 space-y-2 text-base-content/70">
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>ERN 3.8.2 and 4.3 support</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Extracts releases, tracks, artists, deals, territories, labels</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>ISRC and UPC validation</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Automatic version detection from XML namespace</span>
            </li>
          </ul>
        </:description>
        <:code>
          <.code_block title="Supported ERN structure" code={@ern_code} />
        </:code>
      </.feature_section>

      <%!-- Secure File Storage --%>
      <.feature_section id="file-storage" bg="bg-base-200/50">
        <:icon><.icon name="hero-cloud-arrow-up" class="size-8 text-primary" /></:icon>
        <:title>Secure File Storage</:title>
        <:description>
          <p>Audio files, artwork, and XML are stored on S3-compatible storage (Tigris) with presigned URLs. Every file path is scoped to the owning tenant.</p>
          <ul class="mt-4 space-y-2 text-base-content/70">
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Presigned URLs for secure download</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Tenant-isolated paths: <code class="bg-base-300 px-1.5 py-0.5 rounded text-sm">tenants/org/deliveries/id/...</code></span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Checksums and integrity verification</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Lifecycle: upload → stored → purged</span>
            </li>
          </ul>
        </:description>
        <:code>
          <.code_block title="S3 key structure" code={@storage_code} />
        </:code>
      </.feature_section>

      <%!-- Real-time Processing --%>
      <.feature_section id="realtime">
        <:icon><.icon name="hero-bolt" class="size-8 text-primary" /></:icon>
        <:title>Real-time Processing</:title>
        <:description>
          <p>Deliveries are processed asynchronously with Oban workers. PubSub broadcasts status updates in real time, and every step is recorded for a full audit trail.</p>
          <ul class="mt-4 space-y-2 text-base-content/70">
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Async Oban workers with retries and backoff</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>PubSub delivery status updates</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check" class="size-5 text-success shrink-0 mt-0.5" />
              <span>Full audit trail from receipt to completion</span>
            </li>
          </ul>
        </:description>
        <:code>
          <.code_block title="Delivery processing pipeline" code={@realtime_code} />
        </:code>
      </.feature_section>

      <%!-- CTA --%>
      <section class="py-20 bg-base-200/50">
        <div class="mx-auto max-w-3xl px-6 text-center">
          <h2 class="text-3xl sm:text-4xl font-bold text-base-content">Ready to try it?</h2>
          <p class="mt-4 text-base-content/60 text-lg">
            Upload a DDEX XML file and see how it becomes a queryable API in seconds.
          </p>
          <div class="mt-8 flex flex-col sm:flex-row items-center justify-center gap-4">
            <.link navigate={~p"/demo"} class="btn btn-primary btn-lg gap-2 px-8">
              Try the demo
              <.icon name="hero-arrow-right" class="size-5" />
            </.link>
            <a href="/api/json/swaggerui" class="btn btn-outline btn-lg gap-2">
              <.icon name="hero-document-text" class="size-5" />
              API Docs
            </a>
          </div>
        </div>
      </section>

      <%!-- Footer --%>
      <footer class="py-12 border-t border-base-300">
        <div class="mx-auto max-w-5xl px-6">
          <div class="flex flex-col sm:flex-row items-center justify-between gap-4">
            <div class="flex items-center gap-2">
              <.icon name="hero-musical-note" class="size-5 text-primary" />
              <span class="font-semibold">DDEX Delivery Service</span>
            </div>
            <div class="flex items-center gap-6">
              <.link navigate={~p"/"} class="text-sm text-base-content/50 hover:text-base-content transition-colors">
                Home
              </.link>
              <.link navigate={~p"/demo"} class="text-sm text-base-content/50 hover:text-base-content transition-colors">
                Demo
              </.link>
            </div>
            <p class="text-sm text-base-content/50">
              Built with Elixir, Phoenix & Ash Framework
            </p>
          </div>
        </div>
      </footer>
    </div>
    """
  end

  defp feature_section(assigns) do
    bg = assigns[:bg] || ""
    assigns = assign(assigns, :bg, bg)

    ~H"""
    <section id={@id} class={"py-20 #{@bg}"}>
      <div class="mx-auto max-w-5xl px-6">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-start">
          <div>
            <div class="w-14 h-14 rounded-xl bg-primary/10 flex items-center justify-center mb-6">
              {render_slot(@icon)}
            </div>
            <h2 class="text-3xl font-bold text-base-content mb-4">
              {render_slot(@title)}
            </h2>
            <div class="text-base-content/70 leading-relaxed">
              {render_slot(@description)}
            </div>
          </div>
          <div>
            {render_slot(@code)}
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :code, :string, required: true

  defp code_block(assigns) do
    ~H"""
    <div class="rounded-xl border border-base-300 overflow-hidden">
      <div class="bg-base-300/50 px-4 py-2 text-sm font-medium text-base-content/70 border-b border-base-300">
        {@title}
      </div>
      <pre class="bg-base-200 p-4 overflow-x-auto text-sm leading-relaxed"><code class="text-base-content/80">{@code}</code></pre>
    </div>
    """
  end
end
