# -*- encoding : utf-8 -*-
class Platforms::MaintainersController < ApplicationController
  # External callbacks from bugzilla
  ET_CALLBACKS = [:assignee]
  before_filter :authenticate_user!, :except => ET_CALLBACKS
  load_and_authorize_resource :platform, :except => ET_CALLBACKS

  # external callbacks are authorized with a lightweight scheme: they should only come from a specified IP addresses
  before_filter :authenticate_external_tracker!, :only => ET_CALLBACKS

  def index
    # Let's build a relation to query maintainers via 'build_list_packages' table
    @maintainers = BuildList::Package.maintainers.where(:platform_id => @platform).order('lower(name) ASC').includes(:project).paginate(:page => params[:page])
  end

  # Given platform_id, and the string that contains source or binary package name, or project name, find the email of the assignee of the project that contains the given package under the platform specified.
  def assignee
    ret = {}
    # NOTE that platform is looked up here to handle the error of platform being not found
    @platform = Platform.find(params[:platform_id]) rescue ''
    @package = params[:package]
    if @platform.blank?
      ret[:error] = "ABF platform ##{params[:platform_id]} not found!"
    elsif @package.blank?
      # TODO: maybe, it should be the special case for "default" maintainer for the platform?
      ret[:error] = "Package not specified"
    else
      # Ok, find a maintainer, and return it, if any.  If source and binary package have the same name, we do not distinguish because most likely they'll have same assignee.
      if maintainer = BuildList::Package.maintainers.where(:platform_id => @platform, :name => @package).includes(:project).first
        ret[:assignee] = maintainer.assignee.email
      # Package is not found; look for a project for this platform
      elsif proj_id = @platform.repositories.joins(:projects).where(["projects.name = ?",@package]).select('projects.id').map(&:id).first
        # Try to find a project?
        begin
          ret[:assignee] = Project.find(proj_id).assignee.email
        rescue
          ret[:error] = 'Not found'
        end
      else
        ret[:error] = 'Not found'
      end
    end
    respond_to do |format|
      format.json {render :json => ret}
      format.js {@ret = ret}
    end
  end

  protected
  def authenticate_external_tracker!
    if request.remote_ip != APP_CONFIG['external_tracker_ip']
      render :nothing => true, :status => 403
    end
  end
end

