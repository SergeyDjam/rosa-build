module BuildListsHelper

  # See: app/assets/javascripts/angularjs/models/build_list.js.erb
  def build_list_status_color(status)
    case status
    when BuildList::BUILD_PUBLISHED, BuildList::SUCCESS, BuildList::BUILD_PUBLISHED_INTO_TESTING
      'success'
    when BuildList::BUILD_ERROR, BuildList::FAILED_PUBLISH, BuildList::REJECTED_PUBLISH, BuildList::FAILED_PUBLISH_INTO_TESTING, BuildList::PACKAGES_FAIL, BuildList::UNPERMITTED_ARCH
      'error'
    when BuildList::TESTS_FAILED
      'warning'
    else
      'nocolor'
    end
  end

  def can_run_dependent_build_lists?(build_list)
    build_list.save_to_platform.main? &&
    build_list.save_to_platform.distrib_type == 'mdv'
  end

  def availables_main_platforms
    Platform.availables_main_platforms current_user
  end

  def dependent_projects(package)
    return [] if package.dependent_packages.blank?

    packages = BuildList::Package.
      select('build_list_packages.project_id, build_list_packages.name').
      joins(:build_list).
      where(
        platform_id:  package.platform,
        name:         package.dependent_packages,
        package_type: package.package_type,
        build_lists:  { status: BuildList::BUILD_PUBLISHED }
      ).
      group('build_list_packages.project_id, build_list_packages.name').
      reorder(:project_id).group_by(&:project_id)

    Project.where(id: packages.keys).recent.map do |project|
      [
        project,
        packages[project.id].map(&:name).sort
      ]
    end
  end

  def external_nodes
    BuildList::EXTERNAL_NODES.map do |type|
      [I18n.t("layout.build_lists.external_nodes.#{type}"), type]
    end
  end

  def auto_publish_statuses
    BuildList::AUTO_PUBLISH_STATUSES.map do |status|
      [I18n.t("layout.build_lists.auto_publish_status.#{status}"), status]
    end
  end

  def mass_build_options
    options_for_select(
      MassBuild.recent.limit(15).pluck(:name, :id).unshift([t(:none), -1])
    )
  end

  def build_list_options_for_new_core
    [
      [I18n.t("layout.true_"), 1],
      [I18n.t("layout.false_"), 0]
    ]
  end

  def build_list_item_status_color(status)
    case status
    when BuildList::SUCCESS
      'success'
    when BuildList::BUILD_ERROR, BuildList::Item::GIT_ERROR #, BuildList::DEPENDENCIES_ERROR
      'error'
    else
      ''
    end
  end

  def build_list_classified_update_types
    advisoriable    = BuildList::RELEASE_UPDATE_TYPES.map do |el|
      [el, {class: 'advisoriable'}]
    end
    nonadvisoriable = (BuildList::UPDATE_TYPES - BuildList::RELEASE_UPDATE_TYPES).map do |el|
      [el, {class: 'nonadvisoriable'}]
    end

    return advisoriable + nonadvisoriable
  end

   def build_list_item_version_link(item, str_version = false)
    hash_size=5
    if item.version =~ /^[\da-z]+$/ && item.name == item.build_list.project.name
      bl = item.build_list
      {
        text: str_version ? "#{shortest_hash_id item.version, hash_size}" : shortest_hash_id(item.version, hash_size),
        href: commit_path(bl.project, item.version)
      }
    else
      {}
    end
  end

  def build_list_version_name(bl)
    hash_size=5
    if bl.commit_hash.present?
      if bl.last_published_commit_hash.present? && bl.last_published_commit_hash != bl.commit_hash
        "#{shortest_hash_id bl.last_published_commit_hash, hash_size}...#{shortest_hash_id bl.commit_hash, hash_size}"
      else
        shortest_hash_id(bl.commit_hash, hash_size)
      end
    else
      bl.project_version
    end
  end

  def get_build_list_version_path(bl)
    if bl.commit_hash.present?
      if bl.last_published_commit_hash.present? && bl.last_published_commit_hash != bl.commit_hash
        diff_path(bl.project, bl.last_published_commit_hash) + "...#{bl.commit_hash}"
      else
        commit_path(bl.project, bl.commit_hash)
      end
    else
      nil
    end
  end

  def build_list_version_link(bl)
    hash_size=5
    if bl.commit_hash.present?
      if bl.last_published_commit_hash.present? && bl.last_published_commit_hash != bl.commit_hash
        link_to "#{shortest_hash_id bl.last_published_commit_hash, hash_size}...#{shortest_hash_id bl.commit_hash, hash_size}",
                diff_path(bl.project, bl.last_published_commit_hash) + "...#{bl.commit_hash}"
      else
        link_to shortest_hash_id(bl.commit_hash, hash_size), commit_path(bl.project, bl.commit_hash)
      end
    else
      bl.project_version
    end
  end

  def product_build_list_version_link(bl, str_version = false)
    if bl.commit_hash.present?
      link_to str_version ? "#{shortest_hash_id bl.commit_hash} ( #{bl.project_version} )" : shortest_hash_id(bl.commit_hash),
        commit_path(bl.project, bl.commit_hash)
    else
      bl.project_version
    end
  end

  def container_url(build_list = @build_list)
    url = "#{APP_CONFIG['downloads_url']}/#{build_list.save_to_platform.name}/container/#{build_list.id}/"
    if ['dnf', 'mdv'].include?(build_list.build_for_platform.try(:distrib_type))
      url << "#{build_list.arch.name}/#{build_list.save_to_repository.name}/release/"
    end
    url.html_safe
  end

  def can_publish_in_future?(bl)
    [
      BuildList::SUCCESS,
      BuildList::FAILED_PUBLISH,
      BuildList::BUILD_PUBLISHED,
      BuildList::TESTS_FAILED,
      BuildList::BUILD_PUBLISHED_INTO_TESTING
    ].include?(bl.status)
  end

  def log_reload_time_options
    t = I18n.t("layout.build_lists.log.reload_times").map { |i| i.reverse }

    options_for_select(t, t.first).html_safe
  end

  def log_reload_lines_options
    options_for_select([100, 200, 500, 1000, 1500, 2000], 1000).html_safe
  end

  def get_version_release build_list
    pkg = build_list.source_packages.first
    "#{pkg.version}-#{pkg.release}" if pkg.present?
  end

  def new_build_list_data(build_list, project, params)
    res = {
            build_list_id:         params[:build_list_id],
            name_with_owner:       project.name_with_owner,
            build_for_platform_id: params[:build_list].try(:[], :build_for_platform_id),
            save_to_repository_id: save_to_repository_id(params),
            project_version:       project_version(project, params),

            platforms:             new_build_list_platforms(params),
            save_to_repositories:  save_to_repositories(project, params),
            project_versions:      build_list_project_versions(project),
            arches:                arches(params),
            default_extra_repos:   default_extra_repos(project),
            extra_repos:           extra_repos(params),
            extra_build_lists:     extra_build_lists(params),
            auto_create_container: default_auto_create_container(params, build_list),
            auto_publish_status:   params[:build_list].try(:[], :auto_publish_status)
          }
    res.to_json
  end

  def is_repository_checked(repo, params)
    include_repos(params).include? repo.id.to_s
  end

  def filter_by_save_to_platform
    pls = availables_main_platforms
    pls = pls.select{ |p| current_user_platforms.include?(p.id) } if current_user_platforms.present?
    pls.map{ |pl| [pl.name, pl.id] }
  end

  private

  def save_to_repositories(project, params)
    project.repositories.map do |r|
      # Show only main platforms which user used as default.
      next if r.platform.main? && current_user_platforms.present? && current_user_platforms.exclude?(r.platform.id)
      {
        id:                 r.id,
        name:               "#{r.platform.name}/#{r.name}",
        publish_without_qa: r.publish_without_qa?,
        repo_name:          r.name,
        platform_id:        r.platform.id,
        default_branch:     r.platform.default_branch,
        default_arches:     ( r.platform.platform_arch_settings.by_default.pluck(:arch_id).presence ||
                              Arch.where(name: Arch::DEFAULT).pluck(:id) )
      }
    end.compact.sort_by { |e| e[:name] }
  end

  def new_build_list_platforms(params)
    availables_main_platforms.map do |pl|
      # Show only main platforms which user used as default.
      next if current_user_platforms.present? && current_user_platforms.exclude?(pl.id)
      platform = { id: pl.id, name: pl.name, repositories: [] }
      Repository.custom_sort(pl.repositories).each do |repo|
        platform[:repositories] << { id:       repo.id,
                                     name:     repo.name,
                                     disabled: false,
                                     checked:  is_repository_checked(repo, params) }
      end
      platform
    end.compact
  end

  def current_user_platforms
    @current_user_platforms ||= (current_user.try(:builds_setting).try(:platforms) || []).select(&:present?).map(&:to_i)
  end

  def include_repos(params)
    @include_repos ||= (params.try(:[], :build_list).try(:[], :include_repos) || []).map {|e| e.to_s}
  end

  def save_to_repository_id(params)
    @save_to_repository_id ||= params[:build_list].try(:[], :save_to_repository_id).to_i
  end

  def project_version(project, params)
    @project_version ||= params[:build_list].try(:[], :project_version) || project.resolve_default_branch
  end

  def build_list_project_versions(project)
    return [] unless project
    branches_kind = I18n.t('layout.git.repositories.branches')
    tags_kind     = I18n.t('layout.git.repositories.tags')
    res = []
    project.repo.branches.each do |br|
      res << { name: br.name, kind: branches_kind }
    end
    project.repo.tags.each do |t|
      res << { name: t.name, kind: tags_kind }
    end
    res.sort_by { |e| e[:name] }
  end

  def arches(params)
    Arch.recent.map do |arch|
      {
        id:      arch.id,
        name:    arch.name,
        checked: (params[:arches]||[]).include?(arch.id) ||
                   (params[:arches].blank? &&
                    controller.action_name == 'new' &&
                    Arch::DEFAULT.include?(arch.name))
      }
    end
  end

  def default_extra_repos(project)
    scope = project.repositories.joins(:platform).where(platforms: { platform_type: 'personal' })
    scope = PlatformPolicy::Scope.new(current_user, scope).show
    scope.map do |extra|
      {
        id:              extra.id,
        platform_id:     extra.platform.id,
        label:           "#{extra.platform.name}/#{extra.name}",
        path:            url_for([extra.platform, extra])
      }
    end
  end

  def extra_repos(params)
    Repository.where(id: params[:build_list].try(:[], :extra_repositories) ).map do |extra|
      {
        id:    extra.id,
        label: "#{extra.platform.name}/#{extra.name}",
        path:  url_for([extra.platform, extra])
      }
    end
  end

  def extra_build_lists(params)
    BuildList.where(id: params[:build_list].try(:[], :extra_build_lists) ).map do |extra|
      {
        id:    extra.id,
        label: "#{extra.id} (#{extra.project.name} - #{extra.arch.name})",
        path:  url_for(extra)
      }
    end
  end

  def default_auto_create_container(params, build_list)
    checked = params[:build_list].try(:[], :auto_create_container)
    checked = build_list.auto_create_container if checked.nil?
    checked
  end
end
