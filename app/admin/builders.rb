ActiveAdmin.register_page 'Builders' do
  content do
    div class: 'index_as_table' do
      table_for RpmBuildNode.all.to_a, class: "index_table index" do
        column :id
        column :user_id do |b|
          u = User.find_by_id(b.user_id)
          u.present? ? link_to(u.uname, admin_user_path(u.id)) : 'Unknown'
        end
        column :system
        column :host
        column :busy_workers
        column :query_string do |b|
          b.query_string.presence || '-'
        end
        column 'Last build ID' do |b|
          if b.last_build_id.present?
            link_to b.last_build_id, build_list_path(b.last_build_id)
          else
            'None'
          end
        end
      end
    end
  end
end
