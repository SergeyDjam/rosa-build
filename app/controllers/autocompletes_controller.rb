class AutocompletesController < ApplicationController
  before_action     :authenticate_user!
  skip_after_action :verify_authorized

  def autocomplete_user_uname
    results = User.opened.search(params[:query]).search_order.limit(5)
    render json: results.map{ |u| { id: u.id, name: u.uname } }
  end

  def autocomplete_user_or_group
    results << User.opened.search(params[:query]).search_order.limit(5).pluck(:uname)
    results << Group.search(params[:query]).search_order.limit(5).pluck(:uname)
    render json: results.flatten.sort.map{ |r| { id: r, name: r } }
  end

  def autocomplete_extra_build_list
    bl = BuildListPolicy::Scope.new(current_user, BuildList).read.
      for_extra_build_lists(params[:term], save_to_platform).first
    results << {  :id     => bl.id,
                  :value  => bl.id,
                  :label  => "#{bl.id} (#{bl.project.name} - #{bl.arch.name})",
                  :path   => build_list_path(bl)
                } if bl
    render json: results.to_json
  end

  def autocomplete_extra_mass_build
    mb = MassBuild.where(id: params[:term]).first
    results << {
      id:     mb.id,
      value:  mb.id,
      label:  "#{mb.id} - #{mb.name}",
      path:   platform_mass_build_path(mb.save_to_platform, mb)
    } if mb && policy(mb).show?
    render json: results.to_json
  end

  def autocomplete_extra_repositories
    # Only personal and build for platform repositories can be attached to the build
    platforms = PlatformPolicy::Scope.new(current_user, Platform).show.
      includes(:repositories).search(params[:term]).search_order.limit(5).
      where("platforms.platform_type = 'personal' OR platforms.id = ?", params[:build_for_platform_id])
    platforms.each do |platform|
      platform.repositories.each do |repository|
        results <<
          {
            id:              repository.id,
            platform_name:   platform.name,
            repository_name: repository.name,
            label:           "#{platform.name}/#{repository.name}",
            path:            platform_repository_path(platform, repository)
          }
      end
    end
    render json: results.to_json
  end

  protected

  def save_to_platform
    @save_to_platform ||= Platform.find_cached(params[:platform_id])
  end

  def results
    @results ||= []
  end

end
