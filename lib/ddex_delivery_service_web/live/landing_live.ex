defmodule DdexDeliveryServiceWeb.LandingLive do
  use DdexDeliveryServiceWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "DDEX Delivery Service")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen">
      <%!-- Hero Section --%>
      <section class="relative overflow-hidden py-20 sm:py-32">
        <div class="mx-auto max-w-5xl px-6 text-center">
          <div class="inline-flex items-center gap-2 rounded-full bg-primary/10 px-4 py-1.5 text-sm font-medium text-primary mb-8">
            <.icon name="hero-musical-note" class="size-4" />
            <span>DDEX ERN 3.8.2 & 4.3 Support</span>
          </div>

          <h1 class="text-5xl sm:text-7xl font-bold tracking-tight text-base-content">
            DDEX Delivery
            <span class="text-primary">Service</span>
          </h1>

          <p class="mt-6 text-lg sm:text-xl text-base-content/70 max-w-2xl mx-auto leading-relaxed">
            Receive music deliveries. Get a clean API.
            <br class="hidden sm:block" />
            Skip months of XML parsing.
          </p>

          <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
            <.link navigate={~p"/demo"} class="btn btn-primary btn-lg gap-2 px-8">
              Try the demo
              <.icon name="hero-arrow-right" class="size-5" />
            </.link>
            <a href="#how-it-works" class="btn btn-ghost btn-lg">
              Learn more
            </a>
          </div>
        </div>
      </section>

      <%!-- How It Works --%>
      <section id="how-it-works" class="py-20 bg-base-200/50">
        <div class="mx-auto max-w-5xl px-6">
          <div class="text-center mb-16">
            <h2 class="text-3xl sm:text-4xl font-bold text-base-content">How it works</h2>
            <p class="mt-4 text-base-content/60 text-lg">Three steps from XML to API</p>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
            <div class="card bg-base-100 shadow-md">
              <div class="card-body items-center text-center">
                <div class="w-14 h-14 rounded-full bg-primary/10 flex items-center justify-center mb-4">
                  <.icon name="hero-cloud-arrow-up" class="size-7 text-primary" />
                </div>
                <div class="badge badge-primary badge-outline mb-2">Step 1</div>
                <h3 class="card-title">Drop</h3>
                <p class="text-base-content/60">
                  Upload DDEX ERN XML files via browser, API, or SFTP. We accept any standard delivery format.
                </p>
              </div>
            </div>

            <div class="card bg-base-100 shadow-md">
              <div class="card-body items-center text-center">
                <div class="w-14 h-14 rounded-full bg-secondary/10 flex items-center justify-center mb-4">
                  <.icon name="hero-cog-6-tooth" class="size-7 text-secondary" />
                </div>
                <div class="badge badge-secondary badge-outline mb-2">Step 2</div>
                <h3 class="card-title">Parse</h3>
                <p class="text-base-content/60">
                  Automatic validation and parsing of ERN 3.8.2 and 4.3 messages. Releases, tracks, artists, deals &mdash; all extracted.
                </p>
              </div>
            </div>

            <div class="card bg-base-100 shadow-md">
              <div class="card-body items-center text-center">
                <div class="w-14 h-14 rounded-full bg-accent/10 flex items-center justify-center mb-4">
                  <.icon name="hero-code-bracket" class="size-7 text-accent" />
                </div>
                <div class="badge badge-accent badge-outline mb-2">Step 3</div>
                <h3 class="card-title">Consume</h3>
                <p class="text-base-content/60">
                  Access your catalog via REST (JSON:API) or GraphQL. Real-time webhook notifications when new deliveries arrive.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <%!-- Features Grid --%>
      <section class="py-20">
        <div class="mx-auto max-w-5xl px-6">
          <div class="text-center mb-16">
            <h2 class="text-3xl sm:text-4xl font-bold text-base-content">Built for the music industry</h2>
            <p class="mt-4 text-base-content/60 text-lg">Everything you need to receive and serve DDEX deliveries</p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
            <.feature_card
              icon="hero-shield-check"
              title="Tenant Isolation"
              description="Every store gets a fully isolated environment. Pre-release content never leaks between tenants."
            />
            <.feature_card
              icon="hero-key"
              title="API Key Authentication"
              description="Scoped API keys per organization with granular permissions. Programmatic access to your catalog."
            />
            <.feature_card
              icon="hero-code-bracket"
              title="JSON:API + GraphQL"
              description="Standards-compliant REST and GraphQL APIs. Query releases, tracks, artists, deals — however you prefer."
            />
            <.feature_card
              icon="hero-document-check"
              title="ERN 3.8.2 + 4.3"
              description="Full support for both major ERN versions with automatic detection and validation."
            />
            <.feature_card
              icon="hero-cloud-arrow-up"
              title="Secure File Storage"
              description="Audio, artwork, and XML stored with presigned URLs and tenant-isolated S3 paths."
            />
            <.feature_card
              icon="hero-building-office-2"
              title="Multi-Organization"
              description="Each DSP/store runs as an independent tenant with its own users, API keys, and delivery pipeline."
            />
          </div>

          <div class="text-center mt-10">
            <.link navigate={~p"/features"} class="btn btn-outline btn-primary gap-2">
              Learn more about our features
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </div>
      </section>

      <%!-- CTA --%>
      <section class="py-20 bg-base-200/50">
        <div class="mx-auto max-w-3xl px-6 text-center">
          <h2 class="text-3xl sm:text-4xl font-bold text-base-content">See it in action</h2>
          <p class="mt-4 text-base-content/60 text-lg">
            Drop a DDEX XML file and watch it transform into a clean, queryable API in seconds.
          </p>
          <div class="mt-8">
            <.link navigate={~p"/demo"} class="btn btn-primary btn-lg gap-2 px-8">
              Launch the demo
              <.icon name="hero-rocket-launch" class="size-5" />
            </.link>
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
              <.link navigate={~p"/features"} class="text-sm text-base-content/50 hover:text-base-content transition-colors">
                Features
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

  defp feature_card(assigns) do
    ~H"""
    <div class="card bg-base-100 border border-base-300">
      <div class="card-body">
        <div class="w-10 h-10 rounded-lg bg-primary/10 flex items-center justify-center mb-2">
          <.icon name={@icon} class="size-5 text-primary" />
        </div>
        <h3 class="font-semibold text-base-content">{@title}</h3>
        <p class="text-sm text-base-content/60">{@description}</p>
      </div>
    </div>
    """
  end
end
