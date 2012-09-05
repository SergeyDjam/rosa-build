json.platform do |json|
  json.(@platform, :id, :name, :description, :parent_platform_id, :released, :visibility, :platform_type, :distrib_type)
  json.created_at @platform.created_at.to_i
  json.updated_at @platform.updated_at.to_i
  json.owner do |json_owner|
    json_owner.(@platform.owner, :id, :name)
    json_owner.type @platform.owner_type
    json_owner.url @platform.owner_type == 'User' ? user_path(@platform.owner) : group_path(@platform.owner)
  end
end
json.url api_v1_platform_path(@platform, :format => :json)
