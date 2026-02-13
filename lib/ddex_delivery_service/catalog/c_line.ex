defmodule DdexDeliveryService.Catalog.CLine do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :year, :integer, public?: true
    attribute :text, :string, public?: true
  end
end
