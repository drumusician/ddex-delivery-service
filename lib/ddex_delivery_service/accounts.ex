defmodule DdexDeliveryService.Accounts do
  use Ash.Domain,
    otp_app: :ddex_delivery_service

  resources do
    resource DdexDeliveryService.Accounts.Token
    resource DdexDeliveryService.Accounts.User

    resource DdexDeliveryService.Accounts.Organization do
      define :create_organization, action: :create
      define :get_organization_by_id, action: :read, get_by: [:id]
      define :get_organization_by_slug, action: :read, get_by: [:slug]
      define :list_organizations, action: :read
    end

    resource DdexDeliveryService.Accounts.Membership do
      define :create_membership, action: :create
      define :list_memberships, action: :read
    end

    resource DdexDeliveryService.Accounts.ApiKey do
      define :create_api_key, action: :create
      define :list_api_keys, action: :read
      define :destroy_api_key, action: :destroy
      define :lookup_api_key_by_hash, action: :lookup_by_hash, args: [:key_hash]
    end

    resource DdexDeliveryService.Accounts.SftpKey do
      define :create_sftp_key, action: :create
      define :list_sftp_keys, action: :read
      define :list_active_sftp_keys, action: :active_keys
      define :get_sftp_key_by_fingerprint, action: :by_fingerprint, args: [:fingerprint]
      define :update_sftp_key, action: :update
      define :destroy_sftp_key, action: :destroy
    end

    resource DdexDeliveryService.Accounts.Connection do
      define :create_connection, action: :create
      define :list_connections, action: :read
      define :get_connection_by_id, action: :read, get_by: [:id]
    end
  end
end
